# DroneAid

> Drone-based relief-supply delivery simulator for civilians impacted by war. Mobile app (Flutter) + serverless backend (Firebase). Built with Claude Code as a documented, agent-assisted workflow.

**CSC291 group project · KMUTT · 2026**

---

## Status

| | |
|---|---|
| Phase | Day 1 bootstrap complete · feature work in progress |
| Deadline | **2026-06-04** |
| App code in `app/` | ✅ all design-spec pages implemented (P-U-01..P-U-09, P-A-01..P-A-07); role-aware shells (user bottom-nav, admin top-tabs + More sheet) |
| Cloud Functions in `functions/` | ✅ 14 functions wired end-to-end on emulator (callables + scheduled `tickFlights` + `onUserCreated`/`onFlightWritten` triggers); `src/lib/*` (admin, roles, fcm, geo, sim, weather) implemented |
| Docs in `docs/` | ✅ complete |

## Team

| Role | Name | GitHub handle |
|---|---|---|
| Lead · Backend + integration | Aok | [@AokDesu](https://github.com/AokDesu) |
| Identity + shared UI | Belle | [@BBelleysp](https://github.com/BBelleysp) |
| Request domain | Bew | [@SNOWxSAUSAGES](https://github.com/SNOWxSAUSAGES) |
| Tracking + maps | Poom | [@Mrmo0p](https://github.com/Mrmo0p) |
| Fleet domain | Tawan | [@Tantawan7](https://github.com/Tantawan7) |

Domains, dependencies, and RACI per page in [`docs/00-team-raci.md`](docs/00-team-raci.md).

## What's in here

```
.
├── docs/                                 All documentation (start here)
│   ├── README.md                         Reading-order index
│   ├── 00-team-raci.md
│   ├── 01-concepts.md                    Problem + 50 F-IDs
│   ├── 02-backlog-delphi.xlsx            Wideband Delphi backlog
│   ├── 03-personas.docx
│   ├── 04-journey-map.md
│   ├── 05-gantt.xlsx                     41-task GANTT, 14 days
│   ├── 06-wbs.md                         Mindmap + linear estimate
│   ├── 07-software-architecture.md       C4 diagrams
│   ├── 08-implementation-diagram.md      Deployment + sequences + state + ER
│   ├── 09-page-flow-design.md            Every page + every flow (Claude Code reads this)
│   ├── agent-logs/                       Per-dev Claude Code session logs
│   ├── diagrams/                         Rendered PNGs
│   └── superpowers/specs/                Master design spec
├── app/                                  Flutter app (Android primary)
│   ├── lib/                              main.dart, core/, features/, utils/, firebase_options.dart
│   ├── android/                          Generated Android platform scaffolding
│   ├── pubspec.yaml / pubspec.lock       Dart deps
│   └── test/                             Widget + unit tests
├── functions/                            Cloud Functions (TypeScript)
│   ├── src/callable/                     onCall handlers (user + admin)
│   ├── src/scheduled/                    onSchedule handlers (tickFlights)
│   ├── src/triggers/                     Firestore + Auth triggers
│   ├── src/lib/                          Shared helpers (admin, roles, fcm, sim, weather, geo)
│   ├── src/seed/                         Emulator seed scripts
│   └── package.json                      Node 22, jest, eslint
├── firebase.json                         Emulator ports + functions build settings
├── .firebaserc                           Active Firebase project (droneaid-csc291)
├── firestore.rules                       Security rules
├── firestore.indexes.json                Composite indexes
├── scripts/                              Helper scripts (xlsx/docx generators + agent-log tooling)
├── .claude/                              Project-scoped Claude Code config
│   ├── agents/                           architect / engineer / qa / security-reviewer
│   └── settings.json                     Permissions + SessionEnd hook
├── .github/                              CODEOWNERS, PR template, CI workflows
├── .gitignore
├── LICENSE                               MIT
└── README.md                             (you are here)
```

## Tech stack

- **Mobile:** Flutter (Android primary, iOS stretch). Riverpod, go_router, flutter_map + OpenStreetMap.
- **Backend:** Firebase — Auth (email/password, synthetic email from national ID), Firestore (realtime), Cloud Functions (TypeScript, callable + scheduled + Firestore triggers), Cloud Messaging (FCM).
- **Local dev:** Firebase Emulator Suite.
- **CI/CD:** GitHub Actions.

Full rationale in [`docs/superpowers/specs/2026-05-19-drone-relief-design.md`](docs/superpowers/specs/2026-05-19-drone-relief-design.md) §2.

## How to read these docs

For humans: [`docs/README.md`](docs/README.md) gives the recommended reading order.

For Claude Code / coding agents: read in this order before writing any code —
1. `docs/superpowers/specs/2026-05-19-drone-relief-design.md` (master spec)
2. `docs/09-page-flow-design.md` (per-page + per-flow contracts)
3. `docs/00-team-raci.md` (ownership and dependency rules)
4. `docs/adr/` (architecture decisions — scope, dev env, widget pattern)
5. `.claude/agents/*` (subagent role definitions)

## Setup

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter | 3.22+ | `flutter --version` |
| Node | 22.x | `functions/package.json` pins `engines.node` to 22 (Cloud Functions runtime). Higher local versions work but emit an `EBADENGINE` warning. |
| Firebase CLI | latest | `firebase --version`. Log in once with `firebase login`. |
| JDK | 17+ | Required by the Firestore emulator. On Arch: `sudo pacman -S jdk-openjdk`. |
| Android SDK + emulator | API 33+ | Or a real device with USB debugging. |
| Python | 3.13+ | For helper scripts in `scripts/`. |
| `npx @mermaid-js/mermaid-cli` | — | Only needed to re-render diagrams. |

### One-time, per developer

1. **Clone** the repo.
2. **Set your handle** so the Claude Code session-log hook knows where to write. Add to your shell rc (e.g. `~/.bashrc`) AND, if you use Hyprland-style launchers that don't source `bashrc`, also to your compositor's env config:
   ```bash
   export DRONE_AID_HANDLE=aok    # one of: aok belle bew poom tawan
   ```
3. **Select the Firebase project**:
   ```bash
   firebase login
   firebase use droneaid-csc291      # already wired in .firebaserc
   ```
4. **Install dependencies**:
   ```bash
   cd app && flutter pub get
   cd ../functions && npm install     # first time; subsequent installs can use `npm ci`
   ```
5. **Firebase client config** — `app/lib/firebase_options.dart` is committed for the shared `droneaid-csc291` project, so this step is only needed if you target a different Firebase project (e.g. a personal sandbox):
   ```bash
   dart pub global activate flutterfire_cli   # if not already installed
   flutterfire configure --project=droneaid-csc291 --platforms=android --yes
   ```
6. **Build Cloud Functions** — *optional, only if you want to verify the toolchain before first run*. `bun scripts/dev.ts` builds + watches automatically, so most days you can skip this.
   ```bash
   cd functions && npm run build
   ```

### Daily run loop

**One-shot runner** — builds functions, starts emulators, waits for them to be ready, seeds on first run, runs `tsc --watch` for live function reload, then runs the app concurrently. Ctrl-C tears everything down. Emulator state persists between runs in `./.emulator-data/` (gitignored).

```bash
bun scripts/dev.ts
```

First time only — install Bun once per machine:

```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"

# Or via npm (cross-platform):
npm install -g bun
```

- **First run**: no `./.emulator-data/` yet → seeds run, state exports to that dir on Ctrl-C.
- **Subsequent runs**: imports from `./.emulator-data/`, **skips seed**, runs app. Accounts you registered last session, requests you submitted, drones, etc. all still there.
- **Wipe + reseed** (for a clean slate):
  ```bash
  rm -rf .emulator-data       # PowerShell: Remove-Item -Recurse -Force .\.emulator-data
  bun scripts/dev.ts          # next run reseeds
  ```

Pass through to `flutter run`: e.g. `bun scripts/dev.ts -d emulator-5554`.

Emulator UI at <http://127.0.0.1:4000>.

### Demo accounts (seeded)

| Role  | National ID    | Password   | What you see                                                |
| ----- | -------------- | ---------- | ----------------------------------------------------------- |
| User  | 1100000000105  | Demo#101   | Mali — has the seeded `demo-flight-001` enroute             |
| Admin | 1100000000008  | Admin#001  | Admin dashboard (Requests · Drones · Control · More)        |

The login page's debug-mode card mirrors this table for quick copy-paste.

**Edit loop while `dev.ts` is running**:
- Edit a `.dart` file → press `r` in the flutter terminal for hot reload (`R` for hot restart).
- Edit a `.ts` file under `functions/src/` → tsc-watch rebuilds `lib/*.js` → the functions emulator auto-reloads. No manual restart needed.

**Manual (two terminals)** — if you want the emulator running across multiple `flutter run` invocations:

```bash
# Terminal 1 — backend:
firebase emulators:start --only auth,firestore,functions

# Terminal 2 — seed once (only after emulator is up):
cd functions && GCLOUD_PROJECT=droneaid-csc291 \
  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  npm run seed

# Terminal 3 — app:
cd app && flutter run -d <device-id>
# flutter devices    # to list connected devices/emulators
```

The app talks to the local emulators automatically when built in debug mode. On the Android emulator we reach the host loopback via `10.0.2.2` (wired in `app/lib/main.dart`).

### Known gaps in the local stack

- **`tickFlights` scheduled function does not fire under the emulator** — Firebase doesn't ship a pub/sub emulator for scheduled triggers. Two ways to advance active flights:
  - **Preferred**: tap the **Tick now** FAB on the admin Control page (visible only in `kDebugMode`). It calls the `devTickFlights` callable, which is hard-guarded by `process.env.FUNCTIONS_EMULATOR === "true"` so it cannot run against a real project.
  - **Fallback**: invoke `tickFlights` directly from the Emulator UI's Functions tab.
- **FCM push notifications are not delivered to the device under the emulator.** Server-side calls in `functions/src/lib/fcm.ts` still run and log; clients must mock the receive side until staging. In-app inbox (`P-U-08`) is the user-visible notification surface for the demo — see `docs/adr/0002-scope-full-features-fcm-emulator-exempt.md`.
- **No live deploy.** This is an emulator-only project; deploy workflows have been removed (see PR #7). To run against a real Firebase project later, recreate the workflows from git history and add the `FIREBASE_SERVICE_ACCOUNT` repo secret.

### Demo capture checklist (issue #30)

Drop screenshots into `docs/prototype-screens/live/` next to the design mocks. From a running `bun scripts/dev.ts` + Android emulator:

```bash
# In a third terminal, while the app is running:
cd app && flutter screenshot --out=../docs/prototype-screens/live/<page-id>.png
```

Capture in this order so the screencast can reuse the same flow:

1. `P-U-01` Login — Mali demo creds visible
2. `P-U-03` Home — catalog + cart + pin
3. `P-U-04` Queue — at least one active request
4. `P-U-05` Tracking — drone on map, battery + ETA
5. `P-U-06` Confirm — after admin assigns + ticks complete
6. `P-U-07` History — after one confirmed delivery
7. `P-A-01` Requests — pending + in-flight mix
8. `P-A-02` Request manage — drone picker visible
9. `P-A-05` Control — multiple flights + Tick now FAB

Screencast (60-90 s, narrated):
1. Login as user → submit request.
2. Login as admin (different account) → approve → assign drone.
3. Open Control → tap **Tick now** repeatedly.
4. Back to user → Tracking → Confirm.

## Claude Code agent-log policy

Every team member runs a `SessionEnd` hook that copies their Claude Code session JSONL into `docs/agent-logs/<handle>/`, redacted of secrets. CI gate `log-presence` blocks PRs that touch source unless the author's folder contains a `.jsonl` whose filename starts with the latest commit's date (`YYYY-MM-DD_*.jsonl`). One log per day satisfies every PR opened that day. See [`docs/agent-logs/README.md`](docs/agent-logs/README.md) for setup (Windows + Linux/macOS) and troubleshooting.

## License

[MIT](LICENSE) © 2026 DroneAid Team (Aok, Belle, Bew, Poom, Tawan).
