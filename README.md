# DroneAid

> Drone-based relief-supply delivery simulator for civilians impacted by war. Mobile app (Flutter) + serverless backend (Firebase). Built with Claude Code as a documented, agent-assisted workflow.

**CSC291 group project · KMUTT · 2026**

---

## Status

| | |
|---|---|
| Phase | Documentation complete · implementation starts **2026-05-22** |
| Deadline | **2026-06-04** |
| App code in `app/` | _not yet — Day 1 of implementation_ |
| Cloud Functions in `functions/` | _not yet — Day 1 of implementation_ |
| Docs in `docs/` | ✅ complete |

## Team

| Role | Name | GitHub handle |
|---|---|---|
| Lead · Backend + integration | Aok | [@AokDesu](https://github.com/AokDesu) |
| Identity + shared UI | Belle | _TBD_ |
| Request domain | Bew | _TBD_ |
| Tracking + maps | Poom | _TBD_ |
| Fleet domain | Tawan | _TBD_ |

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
├── scripts/                              Helper scripts (xlsx/docx generators + agent-log tooling)
├── .claude/                              Project-scoped Claude Code config
│   └── agents/                           architect / engineer / qa / security-reviewer
├── .github/                              CODEOWNERS, PR template, CI workflow stubs
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

## Setup (placeholder, finalized Day 1)

Prerequisites:
- Flutter 3.x (`flutter --version`)
- Node 20 (`node --version`)
- Firebase CLI (`firebase --version`)
- Python 3.13 (for helper scripts in `scripts/`)
- `npx @mermaid-js/mermaid-cli` (to re-render diagrams)

Clone, then later:
```bash
# Coming Day 1
cd app && flutter pub get
cd ../functions && npm ci
firebase emulators:start
```

## Claude Code agent-log policy

Every team member runs a `SessionEnd` hook that copies their Claude Code session JSONL into `docs/agent-logs/<handle>/`, redacted of secrets. CI gate `log-presence` blocks PRs that touch source without a matching log for the day. See [`docs/agent-logs/README.md`](docs/agent-logs/README.md).

## License

[MIT](LICENSE) © 2026 DroneAid Team (Aok, Belle, Bew, Poom, Tawan).
