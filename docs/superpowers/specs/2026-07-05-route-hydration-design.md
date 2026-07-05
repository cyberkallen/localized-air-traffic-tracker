# Route Hydration Design

## Goal

Stop paying for route lookups on flights nobody asks for. The app should hydrate route data only for flights it is actively showing or prefetching near the viewport, while the Cloudflare worker keeps one shared cache so repeated route requests across users do not multiply upstream traffic.

## Product Shape

This is a two-stage data flow:

- The worker returns live aircraft lists without route enrichment.
- The app decides which callsigns need route data and asks for them on demand.

That split keeps the main flight list fast and keeps route traffic proportional to what users actually see.

## Core Flow

1. The app requests live flights.
2. The app renders the list immediately.
3. The app identifies the visible rows plus a small lookahead window.
4. The app prefetches route data for those callsigns in the background.
5. The worker checks the shared cache first.
6. On cache miss, the worker calls `adsbdb`, stores the result, and returns it.

The route request should never block the initial flight list.

## API Shape

The worker should expose a narrow route lookup API:

- `GET /flights`
  - Returns live aircraft only
  - Does not include route enrichment
- `GET /route/:callsign`
  - Returns one route lookup on demand
  - Uses cache first, then upstream if needed
- Optional later:
  - `GET /routes?callsign=...&callsign=...`
  - Batch hydration for viewport prefetch if the app needs fewer round trips

The main list payload stays simple. Route lookups are separate and explicit.

## App Behavior

The app owns route hydration.

Rules:

- Fetch routes only for visible rows plus a small buffer ahead of the viewport.
- Prefetch in the background.
- Skip callsigns already present in app state.
- Do not wait for route data before rendering the list.
- Do not request routes for the entire flight set.

This is the right boundary because users do not manually open flights. The app already knows what is visible, so it should drive route requests from that state.

## Worker Behavior

The worker owns upstream protection.

Rules:

- Check shared cache before any upstream call.
- Deduplicate in-flight lookups by normalized callsign.
- Never let a route lookup failure break the live flights response.
- Return cached negative results for a shorter period so dead callsigns do not get retried constantly.

The worker should be the only place that talks to `adsbdb`.

## Cache Policy

Keep the live aircraft cache at 45 seconds.

Route cache policy:

- Positive route hits: 7 days
- Negative or unknown route lookups: 1 day
- In-flight dedupe: always on

Why 7 days:

- Routes do not change as often as live aircraft positions.
- The feature values shared reuse over perfect freshness.
- Longer caching gives every user the benefit of earlier lookups.

This is a conservative starting point. If route freshness becomes a problem, the TTL can be tightened later. Starting too short would waste the whole point of caching.

## Data Contract

A route lookup should return:

- Callsign
- Airline metadata when available
- Origin airport
- Destination airport
- Optional midpoint if the upstream source provides it
- A clear unknown state when route data cannot be resolved

Route data should be normalized before being cached so the same callsign always maps to the same cache key shape.

## Failure Handling

Route lookup failures must fail soft.

Expected behavior:

- Live aircraft list still renders even if route lookup fails
- Upstream rate limits do not break the app
- Negative results are cached briefly
- Stale cached route data is acceptable if it keeps the system usable

The system should prefer partial data over no data.

## Out Of Scope

Not included in this design:

- Scraping Google Search as a primary route source
- Full-list route enrichment on every live fetch
- User-triggered flight expansion behavior
- Route scoring or prediction
- Historical route reconstruction from multiple providers

## Success Criteria

The design is successful if:

- The app only pays for routes it is actually showing
- Multiple users reuse the same cached route results
- The worker stays under upstream limits more reliably
- The first screen remains fast
- Route data can be stale for a while without the system breaking
