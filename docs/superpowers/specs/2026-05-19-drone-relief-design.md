# Drone Relief Delivery — Design Spec

- **Date:** 2026-05-19
- **Project:** CSC291 group project, KMUTT
- **Team size:** 5 developers
- **Timeline:** 2 weeks (10 working days)
- **Status:** Approved by user, pending team review

---

## 1. Problem & Goal

Build a **mobile application** that simulates drone-based delivery of relief supplies to civilians impacted by war. The app has two role-switched portals inside a single Flutter codebase:

- **User portal** — request supplies, watch the assigned drone fly in real time, confirm receipt.
- **Admin portal** — manage requests, dispatch drones, monitor the fleet, control simulated weather and inventory.

The drone fleet is **fully simulated** (no real flight hardware). Each drone has a 15 km radius reachable in ~1 hour under clear weather; bad weather slows it; battery and mechanical faults can abort flights.

### Goals
- Realistic end-to-end delivery flow under multi-user, real-time conditions.
- Demonstrable failure modes (weather/battery/mechanical) drive admin reassignment.
- Server-of-truth state in Firestore; all clients see the same drone position and queue.
- Auditable Claude Code usage (per-dev session logs in repo) per professor's requirement.

### Non-goals (explicit cut for 2 weeks)
- Real weather API integration (admin manually sets weather).
- Real SMS/OTP auth (synthetic email under the hood; phone is profile data only).
- Real payment / fee / scoring system.
- Admin analytics dashboard, audit log (deferred).
- iOS push notifications (Android FCM only; iOS push is stretch).
- KYC / national ID government verification (format + checksum only).

---

## 2. Tech Stack

| Layer | Choice |
|---|---|
| Mobile client | **Flutter** (Android primary, iOS stretch) |
| State management | **Riverpod** |
| Routing | **go_router** |
| Map | **flutter_map** + OpenStreetMap tiles (no API key) |
| Auth | Firebase Auth (email/password, synthetic email `<id>@drone-aid.local`) |
| Database | **Firestore** (realtime) |
| Backend logic | **Firebase Cloud Functions** (TypeScript) |
| Push | **Firebase Cloud Messaging** (FCM) |
| Scheduled jobs | Cloud Functions `onSchedule` (every 60s) |
| Local dev | Firebase Emulator Suite (Auth + Firestore + Functions) |
| CI/CD | GitHub Actions |

Why not a separate Hono/Elysia backend: Cloud Functions covers callable RPC + scheduled cron + Firestore triggers natively; Firestore covers realtime streams; pulling in a self-hosted server adds Docker + Cloud Run + WebSocket plumbing that the 2-week scope can't absorb. If the team later wants Hono experience, a `functions/` callable can be ported to Hono on Cloud Run without changing the data model.

---

## 3. Architecture

```
Flutter app (single APK/IPA)
  USER screens | ADMIN screens | SHARED (auth, profile, settings)
       └─────────────┬──────────────┘
                Repository layer
                     │
              Riverpod providers
                     │
       Firebase SDK (Auth / Firestore / FCM / Functions)
                     │
                     ▼
─────────────────  FIREBASE  ─────────────────
 Auth        Firestore        Cloud Functions      FCM
                                  callable: submitRequest, approveRequest,
                                            rejectRequest, assignDrone,
                                            confirmDelivery, cancelRequest,
                                            setWeather, restockItem,
                                            toggleDroneMaintenance
                                  scheduled: tickFlights (every 60s)
                                  triggers : onFlightWritten -> FCM fan-out
```

### Key decisions

- **One Flutter codebase, role-switched.** `users/{uid}.role` decides which navigator tree mounts after login. No separate admin app.
- **Repository layer** wraps Firestore. Screens never touch the SDK directly; allows mocks in widget tests.
- **Drone position computed client-side** from `flightPlan` (origin, destination, takeoffAt, speedKmh, weatherModifier). Server only writes state transitions. Eliminates per-second writes, keeps free tier safe.
- **State-changing admin actions go through callable Cloud Functions**, never direct Firestore writes. Lets us keep rules simple and centralize business logic + atomic transactions.

---

## 4. Data Model (Firestore)

### Collections

```
users/{uid}
  nationalId         "1234567890123"     (unique, indexed)
  name               string
  phone              string
  role               "user" | "admin"
  deliveryAddress    { lat, lng, label } | null
  locked             bool
  fcmTokens          [string]            (registered devices)
  createdAt          ts

users/{uid}/notifications/{nid}
  type, title, body, requestId?, flightId?, readAt, createdAt

catalog/{itemId}
  name, weightKg, stock, icon, active

requests/{reqId}
  userId
  items              [{ catalogId, qty }]
  totalWeightKg
  deliveryAddress    (snapshot at submit time)
  priority           "normal" | "urgent"
  status             "pending" | "approved" | "rejected" | "in_flight"
                     | "delivered" | "confirmed" | "failed" | "cancelled"
  notes
  decidedBy, decidedAt, rejectReason
  currentFlightId
  createdAt

drones/{droneId}
  name               "DRN-001"
  status             "idle" | "flying" | "charging" | "maintenance" | "offline"
  batteryPct         0..100
  baseLocation       { lat, lng }
  maxPayloadKg       6.0
  currentFlightId    flightId | null
  lastSeenAt

flights/{flightId}
  droneId, requestId, userId
  status             "enroute" | "delivering" | "returning"
                     | "completed" | "aborted" | "failed"
  origin, destination
  takeoffAt, etaAt
  speedKmh           15 (default; weather drops it)
  weatherModifierAtTakeoff  1.0 | 0.7 | 0.0
  batteryAtTakeoff
  failureType        null | "weather" | "battery" | "mechanical"
  tickHistory        [ { ts, lat, lng, batteryPct, event } ]  (capped, optional)

weather/current   (single document)
  state              "clear" | "wind" | "storm"
  updatedBy, updatedAt
```

### Modeling notes

- **Flight separate from request.** A request may spawn multiple flight attempts (reassign after failure). Request is "what user wants"; flight is "delivery attempt".
- **Snapshot address on request** so request retains original target even if user later moves the pin.
- **Stock lives on catalog**, decremented atomically inside `approveRequest`.
- **Position is derived, not stored.** Saves ~3,600 writes/hour per active drone.

---

## 5. Auth, Roles, Identity

- Registration form collects: national ID (13 digits + checksum validated), password, name, phone, optional delivery pin.
- Firebase Auth uses synthetic email `<id>@drone-aid.local` so the email/password provider works without real email.
- On first sign-in, a Cloud Function trigger (`onUserCreated`) provisions `users/{uid}` with `role: "user"`.
- Admin accounts are seeded via `seedAdmins.ts` script (one-time, idempotent).
- ID checksum logic lives in `app/lib/utils/thai_id_validator.dart` AND `functions/src/lib/id.ts`; both validated by tests.

---

## 6. Pages

### User portal (8 screens)
1. **Login / Register** — ID + password.
2. **Home / Request** — catalog browse, qty picker, address pin on map, submit. Calls `submitRequest`.
3. **Queue** — own requests, live status. Streams `requests where userId == me`.
4. **Tracking** — live map of your drone (filtered to current flight). Streams `flights/{currentFlightId}`; position interpolated client-side.
5. **Confirm** — appears when status == `delivered`; tap to call `confirmDelivery`.
6. **History** — completed / failed / cancelled requests.
7. **Notifications** — in-app inbox; mirrors FCM events.
8. **Profile + Settings** — edit name, phone, delivery pin, language, logout.

### Admin portal (7 screens)
1. **Control (live map)** — all currently flying drones.
2. **Drone list** — all drones incl. offline + maintenance.
3. **Drone detail** — status, battery, current flight, future queue.
4. **Requests** — list of all incoming, filters (status, priority).
5. **Request manage** — open one request, see user profile, approve/reject. On approve, picker shows eligible drones (idle, payload ≥ totalWeightKg, base within range).
6. **Weather panel** — set global weather (clear / wind / storm).
7. **Supply inventory** — list items, restock, toggle active.

---

## 7. End-to-end flow

```
USER                          BACKEND                          ADMIN
[Request page]
  submit ─────────▶  submitRequest()
                       validate items + stock + weight ≤ max drone payload
                       create requests/{id} status=pending
                       FCM ping admins ───────────────▶  [Request list]

                                                            [Request manage]
                                                              approve / reject

                       approveRequest({reqId})  ◀──────
                         tx: stock decrement, status=approved
                         return eligible drones

                                                              pick drone
                       assignDrone({reqId, droneId})  ◀──────
                         tx: create flights/{id} status=enroute
                             takeoffAt=now()
                             etaAt = now + distance / (speedKmh × weatherMod)
                         drone.status=flying, drone.currentFlightId=flightId
                         request.status=in_flight, request.currentFlightId=flightId
                         FCM ping user ─────▶
[Tracking page]                                             [Control map]
  drone moves live                                            drone visible

       ◀──── tickFlights (every 60s) ────▶
         roll failures, advance status

       (no failure)
         delivering → completed
         request.status=delivered
         FCM ping user ─────▶
[Confirm page]
  ✓ confirm ──────▶  confirmDelivery({reqId})
                       request.status=confirmed
                       drone.status=returning → tick brings home → idle
```

Failure branch:
```
tick rolls failureType ∈ {weather, battery, mechanical}
  flight.status = aborted or failed
  request.status = failed
  drone.status = idle (if battery > 0) | maintenance
  FCM ping user + admin
```

---

## 8. Drone simulator engine

### Scheduled tick (Cloud Function, every 60s)
```
tickFlights():
  weather = read weather/current
  flights = query flights where status in [enroute, delivering, returning]

  for f in flights:
    elapsed_hr      = (now - f.takeoffAt) / 3600
    distance_km     = haversine(f.origin, f.destination)
    effective_speed = f.speedKmh × weatherMod(weather, f.status)
    progress        = clamp(elapsed_hr × effective_speed / distance_km, 0, 1)
    battery         = f.batteryAtTakeoff − elapsed_hr × DRAIN_PER_HR(weather)

    if f.status == enroute:
      if weather == storm and rand() < 0.20: → abort("weather")
      if battery < 15                      : → abort("battery")
      if rand() < 0.01                     : → abort("mechanical")

    if aborted:
      f.failureType, f.status = aborted | failed
      request.status = failed
      drone.status = idle | maintenance
      notify(user, admin)

    elif progress >= 1.0 and f.status == enroute:
      f.status = delivering          # 60s soft hold for "landing"
      notify(user, "drone arriving")

    elif progress >= 1.0 and f.status == delivering:
      f.status = completed
      request.status = delivered
      notify(user, "please confirm")

    elif progress >= 1.0 and f.status == returning:
      drone.status = idle, drone.location = base
      f.archived = true
```

### Client position math (every animation frame)
```
elapsed_hr  = (now − flight.takeoffAt) / 3600
duration_hr = haversine(origin, dest) / (speedKmh × weatherModifierAtTakeoff)
t = clamp(elapsed_hr / duration_hr, 0, 1)
lat = lerp(origin.lat, dest.lat, t)
lng = lerp(origin.lng, dest.lng, t)
battery = batteryAtTakeoff − elapsed_hr × DRAIN_PER_HR
```

### Tunable constants
| Constant | Default |
|---|---|
| Base speed | 15 km/h |
| Weather modifier (clear / wind / storm) | 1.0 / 0.7 / 0.0 (storm grounds) |
| Battery drain (base / storm) | 80 / 120 %/hr |
| Storm abort dice per tick | 20% |
| Battery-low threshold | 15% |
| Mechanical dice per tick | 1% |
| Delivering hold | 60s |

**`weatherMod(weather, status)`** — returns 1.0 if status is `delivering` (drone is hovering/landing, weather only affects ground risk via mechanical dice). Otherwise returns the table value above. `returning` uses the same modifier as `enroute`.

**`etaAt`** — set at flight creation: `takeoffAt + (distance_km / (speedKmh × weatherModifierAtTakeoff)) × 3600s`. Re-derived client-side every frame as the user watches.

---

## 9. Security rules (Firestore)

```
users/{uid}
  read    : self OR admin
  create  : self (during register); role forced to "user"
  update  : self for profile fields; admin for {role, locked}

catalog/{id}      read auth ; write admin only
drones/{id}       read auth ; write admin only (and Functions on tick)
weather/current   read auth ; write admin only

requests/{id}
  read    : owner OR admin
  create  : self if userId == auth.uid AND status == "pending"
  update  : DENY (must go through callable)

flights/{id}
  read    : owner of linked request OR admin
  write   : DENY (Functions only)

users/{uid}/notifications/{nid}
  read    : self
  write   : DENY (Functions only)
```

Rules tested via `@firebase/rules-unit-testing` in `firestore.rules.test.ts` (CI gate).

---

## 10. Callable Cloud Functions (the API surface)

**User-callable:**
- `submitRequest(items[], deliveryAddress, priority?, notes?)`
- `cancelRequest(reqId)` — only while pending
- `confirmDelivery(reqId)`
- `updateProfile(fields)`

**Admin-callable:**
- `approveRequest(reqId)`
- `rejectRequest(reqId, reason)`
- `assignDrone(reqId, droneId)`
- `setWeather(state)`
- `restockItem(itemId, qty)`
- `toggleDroneMaintenance(droneId, on)`
- `createCatalogItem(itemData)`

**Internal / scheduled:**
- `tickFlights` — every 60s via `onSchedule`.
- `onFlightWritten` — Firestore trigger, fans out FCM pushes on state transitions.
- `onUserCreated` — Auth trigger, provisions `users/{uid}` with role=user.

Every callable runs as `https.onCall`, validates `context.auth`, enforces role inside the function body.

---

## 11. Repository layout

```
csc291/
├── app/                            Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/                   auth gate, router, theme, env
│   │   ├── data/
│   │   │   ├── models/             User, Request, Drone, Flight, CatalogItem
│   │   │   └── repositories/       *_repo.dart
│   │   ├── providers/              Riverpod providers
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── user/
│   │   │   └── admin/
│   │   ├── widgets/                DroneMap, StatusChip, ItemPicker, BatteryBar
│   │   └── utils/                  geo.dart, thai_id_validator.dart, time_fmt.dart
│   ├── assets/
│   ├── test/
│   └── pubspec.yaml
├── functions/
│   ├── src/
│   │   ├── index.ts
│   │   ├── callable/
│   │   ├── scheduled/
│   │   ├── triggers/
│   │   ├── lib/                    sim/, geo.ts, weather.ts, fcm.ts, id.ts
│   │   └── seed/
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules
├── firestore.indexes.json
├── firebase.json
├── docs/
│   ├── superpowers/specs/
│   └── agent-logs/                 see §13
├── scripts/
│   ├── copy-claude-session.ps1
│   ├── copy-claude-session.sh
│   ├── redact-secrets.py
│   └── build-log-index.py
├── .claude/
│   ├── agents/                     see §14
│   ├── settings.json
│   └── commands/
├── .github/
│   ├── workflows/                  see §15
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
├── .gitattributes
└── README.md
```

---

## 12. Team split & 2-week timeline

### Owners (5 devs)
| Dev | Owns |
|---|---|
| A | Auth + register + profile + settings + shared core (router, theme, ID validator) |
| B | User request flow: catalog browse, cart, pin picker, submit, queue, history |
| C | User tracking + confirm + notifications inbox + FCM client + DroneMap widget |
| D | All admin pages: control, drone list, drone detail, requests, manage, weather, inventory |
| E | Backend: Firestore rules, seed scripts, all Cloud Functions, sim engine, FCM, deploy |

### Day-by-day
**Week 1 — foundation + happy path**
- **Day 1** — E: Firebase project, rules v0, models, seed. A: Flutter scaffold, theme, go_router, Riverpod. All: emulator setup.
- **Day 2** — A: login + register + ID validator (with tests). E: `onUserCreated` trigger. B/C/D: model classes + repository stubs.
- **Day 3** — B: catalog browse + cart. D: admin requests list (read). E: `submitRequest` callable + tests.
- **Day 4** — B: submit + queue (live stream). D: request manage approve/reject. E: `approveRequest` + `rejectRequest` + stock tx.
- **Day 5** — C: tracking page + interpolation math. D: drone list + detail. E: `assignDrone` + flight doc + `tickFlights` v0 (movement only).

**Week 2 — failures, polish, demo**
- **Day 6** — C: confirm + `confirmDelivery` wiring. D: control live map. E: state transitions (delivered → completed).
- **Day 7** — E: failure dice (weather/battery/mechanical). D: weather panel. B: history.
- **Day 8** — A/C: FCM device setup + notifications inbox. E: `onFlightWritten` → FCM. D: inventory + restock.
- **Day 9** — All: integration testing on emulator + real Firebase dev project. Bug bash.
- **Day 10** — All: demo data seed, polish, screenshots, video, README.

### Risks & mitigations
| Risk | Mitigation |
|---|---|
| Firestore rules deny silently | Emulator from Day 1, rules unit tests in CI |
| First tick cold-start lag | Min instances = 1 on `tickFlights`, or accept first-90s delay |
| Map perf with many markers | Cap demo fleet at 8–12 drones |
| Thai ID checksum bugs | Validator + tests on Day 2 |
| iOS push needs APNs cert | Android FCM only; iOS push is stretch |
| 5-dev integration drift | Daily 15-min sync + shared seed dataset |

---

## 13. Claude Code agent-log storage

### Goal
Per professor's requirement, every team member must have their Claude Code session logs. Centralize in the repo so the prof can audit via `git clone`.

### Layout
```
docs/agent-logs/
├── README.md           rules, dev-handle table, setup steps
├── _index.md           auto-generated index (date, dev, session, summary)
├── alice/
│   ├── 2026-05-19_8f3c-...jsonl
│   └── 2026-05-20_a91b-...jsonl
├── bee/
├── chai/
├── dao/
└── eve/
```

### Per-dev setup (one-time)
1. Clone repo, pick a dev handle, create folder `docs/agent-logs/<handle>/`.
2. Add a `SessionEnd` hook to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SessionEnd": [{
         "matcher": "",
         "hooks": [{
           "type": "command",
           "command": "pwsh -File <repo>/scripts/copy-claude-session.ps1"
         }]
       }]
     }
   }
   ```
   (mac/linux uses `scripts/copy-claude-session.sh`.)
3. Script copies `~/.claude/projects/D--projects-csc291/<session>.jsonl` to `docs/agent-logs/<handle>/<date>_<session>.jsonl`, piping through `redact-secrets.py`.
4. End of day: `git add docs/agent-logs/<handle>/ && git commit -m "logs: <date>"`.

### Redaction (`scripts/redact-secrets.py`)
Strips before write:
- Google API keys: `AIza[0-9A-Za-z_-]{35}`
- OpenAI/Anthropic-shaped: `sk-[A-Za-z0-9_-]{20,}`
- OAuth tokens: `ya29\.[A-Za-z0-9_-]+`
- Firebase service account JSON blobs (anything with `private_key` field)
- Bearer tokens: `Bearer [A-Za-z0-9._-]{20,}`
- Email + 13-digit Thai national ID patterns → `[REDACTED]`

### Repo hygiene
- `.gitattributes`: `docs/agent-logs/**/*.jsonl -diff linguist-vendored=true` — clean PR diffs, marked vendored on GitHub.
- `_index.md` regenerated by `scripts/build-log-index.py`, runs in CI on push (see §15).
- Daily commit rule, not per-session — keeps history clean.

---

## 14. Project subagents (`.claude/agents/`)

Committed to repo. Whole team uses the same definitions.

| Agent | Role | Tools | Model |
|---|---|---|---|
| **architect** | Design, schema change proposal, API shape before code | Read, Grep, Glob, WebFetch | opus |
| **engineer** | Implement approved design: Flutter pages, Cloud Functions, refactors | Read, Edit, Write, Grep, Glob, Bash | sonnet |
| **qa** | Unit + widget + integration tests, emulator runs, rules tests | Read, Edit, Write, Grep, Glob, Bash | sonnet |
| **security-reviewer** | Pre-merge audit: rules holes, auth bypass, secret leaks, input validation, callable authorization | Read, Grep, Glob, Bash | opus |

Each agent file (`.claude/agents/<name>.md`) holds frontmatter (name, description, tools, model) + a system prompt that pins the role's responsibilities, refusal boundaries, and output format.

---

## 15. GitHub workflows (`.github/workflows/`)

### CI (`ci.yml`) — runs on PR and push
| Job | Purpose |
|---|---|
| `flutter-test` | `flutter analyze` + `flutter test` in `app/`, pub cache enabled |
| `functions-test` | `npm ci` + `npm run lint` + `npm test` in `functions/` |
| `rules-test` | Firestore emulator + `@firebase/rules-unit-testing` against `firestore.rules` |
| `secrets-scan` | `gitleaks` on diff; fails if a key pattern slipped past redactor |
| `log-presence` | PR must add at least one new `*.jsonl` under `docs/agent-logs/<author-handle>/` if any source file changed. Author handle resolved via `docs/agent-logs/README.md` GitHub-username → handle table. Enforces the class rule. |

### Deploy
~~`deploy-functions.yml`~~ + ~~`deploy-rules.yml`~~ — **deferred, emulator-only**. The class submission runs entirely against the Firebase Emulator Suite on each developer's laptop. To re-enable auto-deploy later, recreate the workflows from git history and add the `FIREBASE_SERVICE_ACCOUNT` repo secret. See `docs/adr/0002-scope-full-features-fcm-emulator-exempt.md`.

### Housekeeping
- `build-log-index.yml` — on push to `docs/agent-logs/**`: regenerate `_index.md`, commit back with `[skip ci]`.
- `claude-review.yml` *(optional, can be dropped to save API budget)* — on PR, invoke the `security-reviewer` subagent against the diff, post findings as PR comment.

### Repo settings
- Single Firebase project `droneaid-csc291` configured in `.firebaserc` but not deployed for the class submission — local emulator only.
- ~~Service account in GitHub Actions secret `FIREBASE_SERVICE_ACCOUNT`.~~ Deferred until deploy is re-enabled.
- `main` branch protected: require CI green + 1 reviewer.
- Branch convention: `feat/<short>`, PR back to `main`.

---

## 16. Acceptance criteria (definition of done)

- A user can register with a valid Thai national ID + password, log in, and reach the Request page.
- A user can submit a request with 1+ catalog items totaling ≤ a drone's max payload.
- An admin can see the new request appear live in the Requests list, open it, approve it, and pick an eligible drone.
- After assignment, the user sees the drone moving on the Tracking page in real time, with live battery + ETA.
- Storm weather (set by admin) can abort an in-flight drone; user + admin both receive notification.
- A delivered (non-failed) request triggers the Confirm page; confirmation moves it to History.
- Drone returns to base after success or failure and resets to `idle`.
- All Firestore writes are mediated by Cloud Functions or guarded by rules; direct client writes to `requests`/`flights`/`drones`/`notifications` are denied.
- CI passes on `main`: flutter tests, functions tests, rules tests, gitleaks, log-presence.
- Every dev has at least one Claude Code session log under `docs/agent-logs/<handle>/` for every day they committed code.
- Demo dataset seeds: 8 drones, 6 catalog items, 1 admin, 3 demo users.

---

## 17. Open questions (resolve during implementation)

- Localization: Thai-only, English-only, or both? (Default: Thai with English fallback.)
- Demo geographic region centroid + extent? (Default: Bangkok metro, 15 km radius.)
- Auto-confirm if user doesn't tap Confirm within N hours? (Default: no, leave it for admin to flag.)
- Drone re-charge time after returning? (Default: instantaneous for demo; can add 5-min cooldown if time permits.)
