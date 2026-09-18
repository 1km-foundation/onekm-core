# onekm_core

Shared foundation for the 1KM Flutter apps (`user`, `provider`, `teams`).
Consumed via path dependency while the repos live side by side; switch to
a git ref when this package gets its own remote:

```yaml
onekm_core:
  git:
    url: https://github.com/1km-foundation/onekm-core.git
    ref: main
```

## What's inside

- `api/` — `OneKmApi` typed-over-JSON client (envelope/meta/error handling
  matching the server contract) + lenient hand-written models. Deliberately
  **not** generated yet: codegen replaces `models.dart` once the OpenAPI
  spec (`GET /api-docs/openapi.json`) stabilizes.
- `auth/` — OTP `Session` (request → verify → JWT + rotating refresh,
  secure storage, proactive rotation, sign-out on auth loss).
- `sync/` — `ReferenceCache` (Hive-backed rate card + config, TTL,
  stale-while-revalidate).
- `net/` — `withRetry` (transport blips + 503s only; business errors and
  429s fail fast), `newIdempotencyKey` (every POST gets one — the server
  replays instead of duplicating), connectivity status stream.
- `l10n/` — supported locales (en, hi reviewed; kn/ta/te registered with
  English fallback pending native review) + shared chrome strings.
- `theme/` — Material 3 tokens (52dp targets, sunlight-readable type).

## Offline posture

Cached reads + retry + banner. Writes are **not** queued locally (rides
and money go through the server state machine); `Idempotency-Key` +
backoff is the rural-network answer. The only safe local draft is
unsent text (dispute descriptions), which a human reconciles.
