# Recall and storm-evacuation collapse to a single transition

A flight in progress can be terminated early in two ways: the admin presses **Recall** on a specific flight, or the admin sets global weather to **storm** which evacuates every `enroute` flight at once. Both paths take the same internal action — flight → `returning` (with the existing tickFlights loop landing the drone normally), Request → `failed`, drone keeps its `flying` status until it lands. The shared helper is `recallFlightTx` in `functions/src/lib/flights.ts`; the two callables (`recallFlight`, `setWeather`) compose validation + notification around it. `delivering` flights are **not** evacuated by storm — the drone is already at the destination, so the package can still be left.

## Considered Options

- **Two divergent transitions.** Rejected — recall and storm-evac would inevitably drift apart (different intermediate states, different drone-status outcomes), and tests for one would not cover the other.
- **Force-abort with `flight → aborted` + `drone → maintenance`.** Rejected — the physical drone is fine; flipping it to `maintenance` requires human action to release it. Letting the drone do a normal return preserves the fleet's availability for the next request.
- **Evacuate `delivering` flights too on storm.** Rejected — `delivering` means the drone is already at the destination doing the 60-second hold. Sending it back without dropping the package strictly *worsens* the outcome of the request that triggered the work.
- **Skip ADR.** Rejected — the "Recall" state is now the only path that mutates a Request out of `in_flight` to `failed` without a per-tick failure roll. A future reader inspecting `setWeather.ts` or `recallFlight.ts` would otherwise have to reverse-engineer that the two callables intentionally share a transition.

## Consequences

- `flights/{flightId}` gains an optional `recalled: true` flag set by `recallFlightTx`, distinguishing admin-or-storm recalls from organic `aborted` outcomes (battery / mechanical / weather-roll).
- `delivering` flights are *not* recallable by either path. If admin needs to halt one (e.g. the user reports an issue mid-hold), the only mechanism is the existing user-side abandonment, then a `report` post-delivery.
- `setWeather` becomes idempotent-ish: re-setting `storm` while it's already storm scans the (now-empty) `enroute` collection and is a cheap no-op.
- `recallFlight` does **not** auto-create a replacement Request. The user must re-submit. This is intentional — the original Request's items / address / urgency may no longer apply by the time conditions clear.
- The `assignDrone` storm-gate (ADR-implicit) is necessary because once storm evacuates in-flight drones, allowing new ones to take off would be incoherent. `assignDrone` already throws `failed-precondition` when `weather === 'storm'`.
- `tickFlights` now also runs two background mechanics on every tick: charging drones held in `maintenance` (+20% per tick to 100), and force-aborting `returning` flights stuck longer than 30 minutes. Neither interacts with the recall path but they share the same scheduled execution.
