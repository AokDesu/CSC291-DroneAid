# DroneAid — Concept & Function List

- **Date:** 2026-05-19
- **Course:** CSC291, KMUTT
- **Team:** Aok (Lead), Belle, Bew, Poom, Tawan
- **Status:** Approved

---

## 1. Problem statement

In active conflict zones, ground supply lines for civilians are dangerous, slow, and unreliable. Relief organizations need to move small, time-critical packages (food kits, water, medical supplies, blankets) over short distances without exposing human couriers to combat or destroyed infrastructure.

Drones provide a fast, low-risk delivery mechanism, but coordinating them at scale requires:

- A way for affected civilians to **request** specific supplies.
- A way for relief coordinators to **vet and dispatch** drones based on payload, range, and current weather.
- A way for everyone to **track delivery in real time**, with visibility into failure conditions (storms, low battery, mechanical fault).

**DroneAid** is a mobile application that simulates this end-to-end system. The drone fleet is fully simulated — no real hardware — but the data model, control loop, and failure modes mirror what a real deployment would face.

## 2. Vision

> A civilian in an impacted area opens DroneAid, picks the relief supplies they need from a catalog, marks a delivery pin on the map, and submits. A coordinator reviews, assigns a drone, and the user watches the drone fly in on a live map. Battery, ETA, and weather are visible the whole time. If a storm aborts the flight, both sides are notified and a new drone is dispatched.

## 3. Goals

1. **End-to-end delivery flow** working under multi-user, real-time conditions.
2. **Realistic simulation** with weather, battery, and mechanical failure modes that affect outcomes.
3. **Single mobile codebase** serving both end-user and admin roles.
4. **Auditable Claude Code usage** — every team member's session logs are committed to the repo (per professor's requirement).
5. **Demonstrable on emulator** for class presentation + screencast.

## 4. Non-goals (scope cut for 2-week timeline)

- Real weather API integration (admin sets weather manually).
- Real SMS/OTP authentication (synthetic email under the hood).
- Government identity verification (format + checksum only, no API call).
- Payment, scoring, or rating system.
- Admin analytics dashboard (deferred).
- iOS push notifications (Android FCM only).
- Multi-tenancy or multi-org support.

## 5. Personas (summary — full versions in `03-personas.docx`)

| Persona | Role |
|---|---|
| **Mali Suwan** (37, refugee mother of two) | Primary user — requests supplies for family in a shelter |
| **Naree Charoen** (29, relief coordinator) | Admin user — vets requests, dispatches drones, monitors fleet |

## 6. Functional list

### 6.1 Authentication & profile

- F-AUTH-01 Register with Thai national ID (13 digits + checksum) + password + name + phone.
- F-AUTH-02 Log in with national ID + password.
- F-AUTH-03 Log out, with FCM token cleanup.
- F-AUTH-04 Edit profile (name, phone, delivery address pin, preferred language).
- F-AUTH-05 Admin can lock/unlock a user account.
- F-AUTH-06 Auto-provision `users/{uid}` document with `role: "user"` on first sign-in.
- F-AUTH-07 Seed admin accounts via one-time script.

### 6.2 Catalog & supply

- F-CAT-01 Display fixed catalog of relief items (name, weight, stock, icon).
- F-CAT-02 Filter catalog to active + in-stock items for user picker.
- F-CAT-03 Admin can create new catalog item.
- F-CAT-04 Admin can restock an item (add to stock).
- F-CAT-05 Admin can deactivate an item (hides from user picker).

### 6.3 Request lifecycle (user side)

- F-REQ-01 Browse catalog and add items to cart with quantity.
- F-REQ-02 Pick delivery pin on map (defaults to profile delivery address).
- F-REQ-03 Submit request; backend validates stock + total weight ≤ max drone payload.
- F-REQ-04 View own queue of requests with live status updates.
- F-REQ-05 Cancel an own request while still pending.
- F-REQ-06 View history of completed / failed / cancelled requests.

### 6.4 Request lifecycle (admin side)

- F-ADM-01 List all pending and active requests, filtered by status and priority.
- F-ADM-02 Open a request and view full user profile + request details.
- F-ADM-03 Approve a request (atomically decrement stock).
- F-ADM-04 Reject a request with a reason string.
- F-ADM-05 Select an eligible drone from a filtered picker (idle, payload OK, base in range).
- F-ADM-06 Assign the selected drone to the request, creating a flight document.

### 6.5 Drone fleet

- F-FLT-01 List all drones including offline + maintenance.
- F-FLT-02 View drone detail: status, battery, current flight, future queue.
- F-FLT-03 Toggle a drone into maintenance mode (removes from picker).
- F-FLT-04 Seed an initial fleet of 8 drones with realistic positions and IDs.

### 6.6 Delivery tracking & simulation

- F-SIM-01 Scheduled Cloud Function `tickFlights` runs every 60 seconds.
- F-SIM-02 Compute drone progress from `takeoffAt`, distance, speed, weather modifier.
- F-SIM-03 Drain battery over elapsed time; faster drain during storm.
- F-SIM-04 Roll three failure types per tick while in flight: weather (20% during storm), battery (< 15%), mechanical (1%).
- F-SIM-05 Transition flight states: enroute → delivering → completed → returning → idle.
- F-SIM-06 Client-side interpolation of drone position every frame using `lerp(origin, destination, t)`.
- F-SIM-07 Show live battery, ETA, and weather state on tracking page.
- F-SIM-08 Admin can globally set weather state to clear / wind / storm.

### 6.7 Delivery confirmation

- F-CFM-01 When status transitions to `delivered`, user sees Confirm page prompt.
- F-CFM-02 User taps Confirm to finalize; request becomes `confirmed`.
- F-CFM-03 Confirmed flight triggers drone return-to-base.
- F-CFM-04 Drone returning + arrived → drone status becomes `idle`.

### 6.8 Notifications

- F-NTF-01 Push notification via FCM on every state transition for owning user.
- F-NTF-02 Push notification to all admins when a new request is submitted.
- F-NTF-03 Push notification to admins on flight failure.
- F-NTF-04 In-app notifications inbox lists all events with read state.
- F-NTF-05 Tap notification jumps to associated request or flight.

### 6.9 Security

- F-SEC-01 Direct client writes to `requests`, `flights`, `drones`, `notifications` are denied by Firestore rules.
- F-SEC-02 All state-changing actions go through callable Cloud Functions.
- F-SEC-03 Callable functions enforce role server-side (`context.auth` + user doc lookup).
- F-SEC-04 `gitleaks` CI gate blocks accidental secret commits.
- F-SEC-05 Local `redact-secrets.py` strips API keys + national IDs from agent logs before commit.

### 6.10 Auditability

- F-AUD-01 Each team member's Claude Code session JSONL copied to `docs/agent-logs/<handle>/` via `SessionEnd` hook.
- F-AUD-02 CI job `log-presence` blocks PRs by author X that touch source but contain no new log under their folder.
- F-AUD-03 Auto-generated `_index.md` lists every session by date + author + summary.

## 7. Tech stack summary

- **Mobile:** Flutter (Android primary, iOS stretch)
- **State:** Riverpod
- **Routing:** go_router
- **Map:** flutter_map + OpenStreetMap tiles
- **Backend:** Firebase (Auth, Firestore, Cloud Functions in TypeScript, FCM)
- **Scheduled jobs:** Cloud Functions `onSchedule`
- **CI/CD:** GitHub Actions
- **Local dev:** Firebase Emulator Suite

(Full rationale in design spec, §2.)

## 8. Acceptance criteria

See design spec §16. Summary:

- Register → submit request → admin approve → admin assign drone → live tracking → confirm receipt → drone returns home → idle.
- Storm weather can abort an in-flight drone; notification reaches user + admin; admin can reassign a new drone.
- All Firestore writes mediated by Cloud Functions or guarded by rules.
- Every dev has at least one Claude Code session log under `docs/agent-logs/<handle>/` for every day they committed code.

## 9. Related documents

- [00 — Team & RACI](00-team-raci.md)
- [02 — Backlog (Wideband Delphi)](02-backlog-delphi.xlsx)
- [03 — Personas](03-personas.docx)
- [04 — User Journey Map](04-journey-map.md)
- [05 — GANTT Chart](05-gantt.xlsx)
- [06 — Work Breakdown Structure](06-wbs.md)
- [07 — Software Architecture](07-software-architecture.md)
- [08 — Implementation Diagram](08-implementation-diagram.md)
- [Design Spec (full)](superpowers/specs/2026-05-19-drone-relief-design.md)
