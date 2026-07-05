# Route Hydration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop precomputing route lookups for every flight and instead hydrate route data only for the flights the app is actively rendering or prefetching, with shared worker-side caching to keep upstream traffic low.

**Architecture:** Keep the live flight feed and route hydration separate. The worker keeps `/flights` fast and route-free, exposes a dedicated `/route/:callsign` lookup, and owns the shared cache plus in-flight dedupe. The web app keeps a tiny route cache of its own, requests the current card immediately, and prefetches a small batch of nearby flights after each flight refresh so the UI feels instant without hammering `adsbdb`.

**Tech Stack:** Node.js, Express, node:test, vanilla JS, `index.html`, browser fetch, existing proxy and mock-proxy scripts.

---

## File Structure

- `server/server.js` owns live flight aggregation, route lookup, route cache, and the new on-demand route endpoint.
- `server/server.test.js` proves `/flights` no longer route-enriches by default and that `/route/:callsign` caches both hits and misses correctly.
- `index.html` switches from direct `adsbdb` fetches to the worker route endpoint, keeps a small client-side route cache, and prefetches the next few flights after every refresh.
- `tools/mock-proxy.js` gets a local `/route/:callsign` endpoint so the app can be smoke-tested against the new flow without hitting production.
- `CLAUDE.md`, `AGENTS.md`, `architecture.html`, and `server/CLAUDE.md` need wording updates so the docs stop describing route lookups as fire-and-forget on `/flights`.

## Task 1: Move route lookup out of `/flights` and into a dedicated worker endpoint

**Files:**
- Modify: `server/server.js`
- Modify: `server/server.test.js`

- [ ] **Step 1: Write the failing tests for on-demand route hydration**

Add these cases to `server/server.test.js`:

```js
describe('GET /flights', () => {
  it('does not populate the route cache', async () => {
    routeCache.clear();
    cache.set('0,0,15', {
      data: { ac: [{ flight: 'QFA1', lat: 0, lon: 0 }] },
      timestamp: Date.now(),
    });

    const res = await get('/flights?lat=0&lon=0&radius=15');
    assert.equal(res.status, 200);
    assert.equal(routeCache.size, 0);
  });
});

describe('GET /route/:callsign', () => {
  it('returns a cached route hit without calling upstream', async () => {
    routeCacheSet('QFA1', { dep: 'YSSY', arr: 'YMML', timestamp: Date.now() });

    const res = await get('/route/QFA1');
    assert.equal(res.status, 200);
    assert.equal(res.body.callsign, 'QFA1');
    assert.equal(res.body.dep, 'YSSY');
    assert.equal(res.body.arr, 'YMML');
    assert.equal(res.body.route, 'Sydney > Melbourne');
  });

  it('returns and caches an unknown route as a soft miss', async () => {
    const res = await get('/route/ZZZ999');
    assert.equal(res.status, 200);
    assert.equal(res.body.callsign, 'ZZZ999');
    assert.equal(res.body.route, null);
    assert.equal(res.body.unknown, true);
  });
});
```

- [ ] **Step 2: Run the server tests and confirm the current code fails**

Run:
`cd server && npm test`

Expected:
The new `/route/:callsign` tests fail because the endpoint does not exist yet, and the `/flights` cache test fails because the current code still enriches routes during the main flight fetch.

- [ ] **Step 3: Implement the smallest worker-side split that makes the tests pass**

Refactor `server/server.js` so it has two separate paths:

```js
// /flights stays focused on live aircraft only.
// It must not call adsbdb or populate routeCache as part of the main response path.

app.get('/route/:callsign', async (req, res) => {
  // Normalize the callsign.
  // Check routeCache first.
  // If stale or missing, dedupe with a routeInFlight map.
  // Fetch adsbdb only here.
  // Return { callsign, dep, arr, route, unknown }.
});
```

Make these concrete code changes:

- Extract the route lookup work from `enrichRoutes(data)` into a dedicated helper such as `resolveRouteForCallsign(cs)`.
- Add a `routeInFlight` map that collapses concurrent lookups for the same callsign.
- Change route cache entries to support both positive and negative results, for example `{ dep, arr, timestamp, unknown }`.
- Increase route TTL from minutes to days. Use a long positive TTL and a shorter negative TTL.
- Keep the existing flight cache, upstream racing, and stats code untouched.

- [ ] **Step 4: Run the server tests again and confirm they pass**

Run:
`cd server && npm test`

Expected:
All existing server tests still pass, plus the new `/route/:callsign` tests pass. The route cache remains shared across requests, but `/flights` no longer burns upstream calls just to discover route data.

- [ ] **Step 5: Commit the proxy split**

```bash
git add server/server.js server/server.test.js
git commit -m "feat: add on-demand route lookup endpoint"
```

## Task 2: Switch the web app to worker route hydration and prefetch the next few flights

**Files:**
- Modify: `index.html`
- Modify: `tools/mock-proxy.js`

- [ ] **Step 1: Write the browser-side failing behavior with a local proxy override**

Add a tiny API-base override in `index.html` so the app can point at a local mock proxy during smoke tests:

```js
const apiBase = new URLSearchParams(window.location.search).get('api') || 'https://api.overheadtracker.com';
const flightsUrl = `${apiBase}/flights?lat={LAT}&lon={LON}&radius={R}`;
const routeUrl = (callsign) => `${apiBase}/route/${encodeURIComponent(callsign)}`;

function normalizeCallsign(value) {
  return (value || '').toString().trim().toUpperCase();
}
```

Then change the existing direct adsbdb route lookup to use the worker endpoint instead of calling `https://api.adsbdb.com/v0/callsign/...`.

Add a local route endpoint to `tools/mock-proxy.js` that returns deterministic route data for a callsign, for example:

```js
if (req.url.startsWith('/route/')) {
  const callsign = decodeURIComponent(req.url.split('/').pop());
  res.writeHead(200, { 'content-type': 'application/json' });
  return res.end(JSON.stringify({
    callsign,
    dep: 'YSSY',
    arr: 'YMML',
    route: 'Sydney > Melbourne',
    unknown: false,
  }));
}
```

Then run the mock proxy and confirm the browser still calls adsbdb directly before the app code is updated:

Run:
`node tools/mock-proxy.js normal 3000 --scenario crowded`

Expected:
Browser network activity still shows direct adsbdb calls and no `/route/...` requests until the app code is changed.

- [ ] **Step 2: Implement on-demand route fetch plus a small prefetch queue**

In `index.html`, replace the direct `adsbdb` call in `lookupRoute(callsign)` with a fetch to the worker route endpoint and cache the result by normalized callsign.

Add a tiny queue so the app does this after each flight refresh:

```js
const PREFETCH_COUNT = 4;

function scheduleRoutePrefetch() {
  const queued = flights.slice(0, PREFETCH_COUNT);
  for (const f of queued) {
    const call = normalizeCallsign(f.flight);
    if (!call) continue;
    if (routeCache.has(call)) continue;
    lookupRoute(call);
  }
}
```

Wire that queue into the existing refresh path after `applyFilterAndSort()` succeeds, and also when the focused flight changes with `next()`, `prev()`, or `go()`.

Keep the render path simple:

- If the focused flight already has route data, render it immediately.
- If it does not, request the worker route endpoint and update just the route row when the promise resolves.
- Ignore stale responses if the user has already moved to another flight.

- [ ] **Step 3: Run the browser smoke check against the mock proxy**

Run:
`node tools/mock-proxy.js normal 3000 --scenario crowded`

Then in a second terminal:
`cd /Users/erikferrari/dev/apps/localized-air-traffic-tracker && python3 -m http.server 8080`

Open:
`http://127.0.0.1:8080/index.html?api=http://127.0.0.1:3000`

Expected:
- The flight list loads from the mock proxy.
- The focused flight requests `/route/:callsign` only when it needs route data.
- The first few nearby flights are prefetched in the background.
- Re-rendering the same callsign reuses the client cache instead of sending another request.

- [ ] **Step 4: Commit the app-side hydration change**

```bash
git add index.html tools/mock-proxy.js
git commit -m "feat: hydrate routes on demand in the web app"
```

## Task 3: Align the docs and architecture notes with the new route flow

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `server/CLAUDE.md`
- Modify: `architecture.html`

- [ ] **Step 1: Confirm the current wording is stale**

The docs currently describe route lookups as fire-and-forget on `/flights` and still imply short route cache windows. That is wrong after the split. Update the prose so it says:

```text
Route lookups are now on-demand via /route/:callsign.
The web app prefetches a small batch of flights after refresh.
The worker caches positive route hits for days, not minutes.
```

- [ ] **Step 2: Update the docs to match the new architecture**

Make these wording changes:

- In `CLAUDE.md`, replace the current route lookup description with the on-demand worker endpoint and the app-side prefetch wording.
- In `AGENTS.md`, update the external API table and the proxy summary so they no longer imply route enrichment happens during the main `/flights` fetch.
- In `server/CLAUDE.md`, replace the stale route-cache note with the new endpoint and TTL behavior.
- In `architecture.html`, change the route cache box and edge labels so they describe the long-lived shared cache and the dedicated `/route` lookup path instead of the old 30 minute fire-and-forget flow.

- [ ] **Step 3: Run the full server regression and a quick static sanity check**

Run:
`cd server && npm test`

Then reload the docs pages in a browser and confirm the route wording matches the new behavior.

Expected:
The server test suite still passes, and the docs no longer describe the old route-enrichment path.

- [ ] **Step 4: Commit the doc refresh**

```bash
git add CLAUDE.md AGENTS.md server/CLAUDE.md architecture.html
git commit -m "docs: update route hydration architecture notes"
```

## Verification Checklist

- `/flights` stays fast and no longer pays for route enrichment.
- `/route/:callsign` is the only place that hits `adsbdb`.
- Positive route hits are cached for days.
- Negative route hits are cached briefly.
- The app prefetches a small route queue after refresh.
- The browser smoke test works against the local mock proxy override.
- No unrelated firmware or screensaver files are touched.
