# Proxy Server (Railway, Node.js/Express)

## Deploy

Use `/railway` skill, or run from the **project root** (not `server/`):

```bash
railway up
```

**CRITICAL:** Railway's root directory setting requires `railway up` to run from the project root. Running it from `server/` causes "Could not find root directory" failures.

Verify: `https://api.overheadtracker.com/status`

## Tests

```bash
cd server && npm test          # 81 unit tests
node server/load-test.js [url] [clients] [duration]
```

## Key Memory Files

- `feedback_railway_deploy.md` — Railway root directory gotcha (must run from project root)
- `architecture.md` — all 9 endpoints, caching strategy, route hydration pipeline, flight logging, email reports

## Route Notes

- Route lookups are served on-demand from `/route/:callsign`.
- Positive route hits are cached for 7 days.
- Negative route hits are cached for 1 day.
- The main `/flights` response must stay route-free.
