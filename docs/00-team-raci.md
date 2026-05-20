# DroneAid — Team Assignment & RACI

- **Project window:** 2026-05-22 → 2026-06-04 (14 days, 7-day work week)
- **Team size:** 5
- **Lead:** Aok
- **Design spec:** [docs/superpowers/specs/2026-05-19-drone-relief-design.md](superpowers/specs/2026-05-19-drone-relief-design.md)

## Domain ownership

| Member | Domain | Primary deliverables |
|---|---|---|
| **Aok** *(Lead)* | Backend + integration + deploy | Firestore rules, all Cloud Functions (callable + scheduled + triggers), sim engine `tickFlights`, FCM fan-out, seed scripts, CI/CD workflows, daily integration sync |
| **Belle** | Identity + shared UI kit | Login, register, profile, settings; shared widgets: `DroneMap`, `BatteryBar`, `StatusChip`, `ItemPicker`; `ThaiIdValidator`; app theme + `go_router` scaffold |
| **Bew** | Request domain (user + admin) | User-side: Request, Queue, History. Admin-side: Requests list, Request Manage (approve/reject + drone picker), Supply Inventory |
| **Poom** | Tracking + maps (user + admin) | User-side: Tracking, Confirm, Notifications inbox, FCM device registration. Admin-side: Control live map |
| **Tawan** | Fleet domain (admin) | Admin-side: Drone list, Drone detail, Weather panel; drone fleet seed data with Aok |

## Why this split enables parallel work

- **Single backend owner (Aok)** publishes data model + callable signatures Day 1. Other members code against the contract using mocked repositories.
- **Belle's shared widgets** consumed by Bew, Poom, Tawan — built first day of feature work so others don't reimplement.
- **Bew owns request lifecycle end-to-end** — no handoff between "user submits" and "admin approves", reducing integration bugs.
- **Poom owns all map-related code** — one expert on `flutter_map` + interpolation math + battery animation.
- **Tawan owns static fleet UI** — independent of live flight code (Poom) and request lifecycle (Bew).

## RACI per page

> R = Responsible, A = Accountable, C = Consulted, I = Informed.

| Page / artifact | Aok | Belle | Bew | Poom | Tawan |
|---|---|---|---|---|---|
| Firestore rules + indexes | **R/A** | I | C | C | C |
| Cloud Functions (callables) | **R/A** | I | C | C | C |
| `tickFlights` sim engine | **R/A** | I | I | C | C |
| FCM trigger fan-out | **R/A** | I | I | C | I |
| CI/CD workflows | **R/A** | I | I | I | I |
| Auth gate + login + register | I | **R/A** | I | I | I |
| Profile + Settings | I | **R/A** | I | I | I |
| Thai ID validator | C | **R/A** | I | I | I |
| Shared widgets (Map, Battery, Chip) | I | **R/A** | C | C | C |
| User Request page | C | C | **R/A** | I | I |
| User Queue page | C | C | **R/A** | I | I |
| User History page | C | C | **R/A** | I | I |
| Admin Requests list | C | I | **R/A** | I | I |
| Admin Request Manage | C | I | **R/A** | I | C |
| Admin Inventory + restock | C | I | **R/A** | I | I |
| User Tracking page | C | C | I | **R/A** | I |
| User Confirm page | C | C | C | **R/A** | I |
| User Notifications inbox | C | I | I | **R/A** | I |
| FCM device registration | C | I | I | **R/A** | I |
| Admin Control (live map) | C | C | I | **R/A** | C |
| Admin Drone list | C | I | I | I | **R/A** |
| Admin Drone detail | C | I | I | C | **R/A** |
| Admin Weather panel | C | I | I | I | **R/A** |
| Drone fleet seed data | C | I | I | I | **R/A** |
| Daily integration sync | **R/A** | C | C | C | C |
| Demo prep + README + screenshots | A | R | R | R | R |

## Dependency map (who blocks whom)

```
Aok ── publishes API contract Day 1 ──▶ Belle, Bew, Poom, Tawan
Belle ── ships shared widgets by Day 4 ──▶ Bew, Poom, Tawan
Aok ── deploys submitRequest by Day 3 ──▶ Bew, Tawan
Aok ── deploys assignDrone by Day 5 ──▶ Poom, Tawan
Aok ── deploys tickFlights by Day 5 ──▶ Poom
Aok ── deploys onFlightWritten + FCM by Day 8 ──▶ Poom
```

Mitigation: every consumer codes against a mock repository until the real Cloud Function ships. Mock + real implement the same Dart interface, swap via Riverpod provider override.

## Communication

- Daily 15-minute standup in Discord/Line group voice room.
- Blockers raised in `#blockers` text channel with `@<owner>`.
- All PRs require 1 reviewer (preferably the consumer of the changed module).
- Spec-level questions: open a GitHub issue with `[design]` prefix; Aok triages.
