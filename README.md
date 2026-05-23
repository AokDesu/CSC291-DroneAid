# DroneAid

> Drone-based relief-supply delivery simulator for civilians impacted by war. Mobile app (Flutter) + serverless backend (Firebase). Built with Claude Code as a documented, agent-assisted workflow.

**CSC291 group project · KMUTT · 2026**

---

## Status

| | |
|---|---|
| Phase | Day 1 bootstrap complete · feature work in progress |
| Deadline | **2026-06-04** |
| App code in `app/` | ✅ runs on Android emulator; placeholder pages — feature work pending |
| Cloud Functions in `functions/` | ✅ builds + loads in emulator (14 functions); `src/lib/*` is minimal stubs |
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
4. `.claude/agents/*` (subagent role definitions)

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
6. **Build Cloud Functions** (TypeScript → JS, needed before the functions emulator can load them):
   ```bash
   cd functions && npm run build
   ```

### Daily run loop

In one terminal — start the local backend:
```bash
firebase emulators:start --only auth,firestore,functions
```
Emulator UI at <http://127.0.0.1:4000>.

In another terminal — start the app:
```bash
cd app && flutter run -d <device-id>
# flutter devices    # to list connected devices/emulators
```

The app talks to the local emulators automatically when built in debug mode. On the Android emulator we reach the host loopback via `10.0.2.2` (wired in `app/lib/main.dart`).

### Known gaps in the local stack

- **`tickFlights` scheduled function does not fire under the emulator** — Firebase doesn't ship a pub/sub emulator for scheduled triggers. Invoke it manually from the Emulator UI's Functions tab when you need a tick.
- **FCM push notifications are not delivered to the device under the emulator.** Server-side calls in `functions/src/lib/fcm.ts` still run and log; clients must mock the receive side until staging.
- **`functions/src/lib/*` are minimal stubs** (`admin`, `roles`, `fcm`, `geo`, `sim`, `weather`). They compile and run end-to-end but are not yet feature-complete — domain owners should flesh them out per the design spec.

## Claude Code agent-log policy

Every team member runs a `SessionEnd` hook that copies their Claude Code session JSONL into `docs/agent-logs/<handle>/`, redacted of secrets. CI gate `log-presence` blocks PRs that touch source without a matching log for the day. See [`docs/agent-logs/README.md`](docs/agent-logs/README.md).

## License

[MIT](LICENSE) © 2026 DroneAid Team (Aok, Belle, Bew, Poom, Tawan).
