# CSC291-DroneAid

Drone-delivery app: users submit delivery Requests, an Admin approves and assigns a Drone, the drone flies, the user confirms or Reports the outcome. Class project on the Firebase Emulator Suite.

## Language

**Request**:
A user's order for a drone delivery: pickup, drop-off, item, urgency. Moves through states `pending → approved → in_flight → delivered → confirmed` (terminal) with branches `rejected`, `cancelled`, `aborted`, `failed`.
_Avoid_: Order, delivery, job, ticket.

**Drone**:
A physical (simulated) aircraft tracked in the `drones/` collection. Has weight/range/weather eligibility per `eligibilityFor`. Admin assigns one Drone per approved Request. While in `maintenance` the drone passively recharges (+20% per tick) until 100% — it does not auto-exit maintenance; an Admin still flips it back to `idle`.
_Avoid_: UAV, vehicle, unit.

**Flight**:
A single execution of a Request by a Drone. Created on approval, ticked toward `completed` by `tickFlights`. Distinct from the Request lifecycle: a Flight can be `completed` while the Request is still `delivered` (not yet confirmed).
_Avoid_: Trip, run, mission.

**Report**:
A user-filed complaint about a Request after the package has been marked `delivered` — including the case where the user disputes the delivery itself (package never arrived, was stolen, wrong item). Filed via `reportDeliveryIssue` callable, stored at `requests/{reqId}/reports/{reportId}`. A Report does NOT require the Request to be `confirmed` first — a user can Report instead of confirming. States: `open → resolved | dismissed`.
_Avoid_: Dispute, incident, claim, complaint, ticket.

**Resolved** (Report state):
Admin reviewed the Report and acted in the user's favour. Admin must pick one of two Request outcomes on resolve:
- **Confirm-with-remedy** — delivery is accepted; Request → `confirmed`. Used when the user got the package but with an issue (wrong item kept, late, minor damage).
- **Fail-the-delivery** — delivery never effectively happened; Request → `failed`. Used when the package was stolen, never arrived, or was destroyed.
Terminal.

**Dismissed** (Report state):
Admin reviewed the Report and declined to act — insufficient evidence, user error, duplicate of another Report. Terminal. Distinct from Resolved so the user knows they were heard but the answer was "no."

**Confirm**:
The user's positive acknowledgement that a delivered package arrived correctly. Transitions Request `delivered → confirmed`. Mutually exclusive with filing a Report against the same delivery in practice, though not yet enforced by rules.
_Avoid_: Accept, acknowledge, sign-off.

**Admin**:
A user with the `admin` role who approves/rejects Requests, assigns Drones, and (now) actions Reports. Single role tier — no separate fleet-operator vs support-agent split.
_Avoid_: Operator, dispatcher, agent, moderator.

**Hub**:
An Admin's personal distribution-hub location, stored as `users/{adminUid}.hubLocation = {lat, lng, label?}`. Visual metadata only — does NOT affect drone dispatch origin, which is still each Drone's own `baseLocation`. Set via the same map pin picker used for user delivery addresses.
_Avoid_: Base, depot, station, warehouse.

**Recall**:
Admin-initiated mid-flight termination. The Flight transitions to `returning`, the Request to `failed`, and the Drone heads home normally (it does not crash or enter maintenance). Two triggers: an admin pressing Recall on a specific Flight, or the system declaring `storm` weather, which evacuates every `enroute` Flight via the same transition. `delivering` Flights — drone already at destination, doing its 60s hold — are NOT recallable; the package can still be left.
_Avoid_: Abort, cancel, force-return.

## Example dialogue

> **Dev:** User just tapped "Something's wrong" on the confirm page. What happens?
> **Domain:** Files a Report against the Request. Request stays in `delivered` — they didn't Confirm. Admin sees the Report, resolves it, Request is then either marked `confirmed` (resolved-in-favour-of-delivery) or stays `delivered` with a resolved Report attached.
>
> **Dev:** Can they Report a Request that's already `confirmed`?
> **Domain:** Yes. Confirming is positive ack but doesn't lock out a later Report — "I confirmed too fast, then found the box was empty." Report is filed against the Request regardless of current status, so long as it's past `delivered`.
>
> **Dev:** What if the Flight is `aborted` mid-air — drone crashed, package never left the warehouse?
> **Domain:** That's not a Report. Request goes to `aborted` automatically; Admin handles ops-side without user input. Report is specifically a user-initiated complaint about a delivery that the system thinks succeeded.
