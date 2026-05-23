# Project "done" = all promised features working on the emulator, FCM-push-to-device exempt

The class submission deadline is 2026-06-05 (deliver to professor) with the demo window closing 2026-06-04 — a 14-day project window starting 2026-05-22. We committed to **full feature parity with the promised behaviour in `docs/09-page-flow-design.md` and `docs/superpowers/specs/2026-05-19-drone-relief-design.md`**, including the simulation polish that lower-scope options would have cut (failure dice, weather effects on flight, admin restock/maintenance flows). The one explicit carve-out is **FCM push notifications to a real device**: the Firebase emulator does not deliver push notifications, so server-side FCM fan-out still runs and is verified by log inspection, but the user-visible notification surface in the demo is the in-app inbox (`P-U-08`), not OS-level push.

## Consequences

- Estimated remaining work is ~37-40 person-days against 60 person-days of remaining capacity (12 days × 5 devs) — buffer is thin.
- "Demo works" means seeded emulator data + happy path + main error states across all 16 prototype screens, not a production Firebase deploy.
- Any feature that depends on FCM push *appearing on a device* must have an inbox-based fallback for the demo.
- Scaling down is allowed only via explicit ADR amendment, not silently per-page.
