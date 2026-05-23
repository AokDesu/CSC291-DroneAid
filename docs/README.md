# DroneAid — Documentation Index

> For the repo-level overview, scaffolding, and setup, see the root [`../README.md`](../README.md).
> Subagent definitions live in [`../.claude/agents/`](../.claude/agents/).
> CI / CODEOWNERS / PR template live in [`../.github/`](../.github/).

CSC291 group project. Drone-based relief-supply delivery simulator (Flutter + Firebase).

- **Team:** Aok (Lead), Belle, Bew, Poom, Tawan
- **Window:** 2026-05-22 → 2026-06-04 (14 days, 7-day work week)
- **Deadline:** 2026-06-04

## Documents

| # | Artifact | File | Notes |
|---|---|---|---|
| 0 | Team & RACI | [`00-team-raci.md`](00-team-raci.md) | Ownership, dependency map, RACI per page |
| 1 | Concept + function list | [`01-concepts.md`](01-concepts.md) | Problem, goals, non-goals, F-IDs for every feature |
| 2 | Backlog (Wideband Delphi) | [`02-backlog-delphi.xlsx`](02-backlog-delphi.xlsx) | 36 user stories × 5 estimators × 3 rounds + consensus + epic/owner rollups |
| 3 | User personas | [`03-personas.docx`](03-personas.docx) | Mali (refugee user) + Naree (admin coordinator) with scenarios |
| 4 | User journey map | [`04-journey-map.md`](04-journey-map.md) + [`diagrams/04-journey-map-*.png`](diagrams/) | Happy path + failure-then-reassign |
| 5 | GANTT chart | [`05-gantt.xlsx`](05-gantt.xlsx) | 41 tasks × 14 days, swimlane, workload, milestones |
| 6 | Work Breakdown Structure | [`06-wbs.md`](06-wbs.md) + [`diagrams/06-wbs-1.png`](diagrams/06-wbs-1.png) | Mindmap + linear estimate table |
| 7 | Software architecture | [`07-software-architecture.md`](07-software-architecture.md) + [`diagrams/07-architecture-*.png`](diagrams/) | C4-style: context, containers, Flutter components, Functions components |
| 8 | Implementation diagrams | [`08-implementation-diagram.md`](08-implementation-diagram.md) + [`diagrams/08-implementation-*.png`](diagrams/) | Deployment, 2 sequences, 3 state machines, ER |
| 9 | Page + flow design (build target) | [`09-page-flow-design.md`](09-page-flow-design.md) | Every screen + every flow with ASCII mockups, Gherkin AC, validation, errors, theme tokens, seed data |
| ★ | Design spec (full) | [`superpowers/specs/2026-05-19-drone-relief-design.md`](superpowers/specs/2026-05-19-drone-relief-design.md) | Source of truth for everything above |
| ADR | Architecture decisions | [`adr/`](adr/) | Hard-to-reverse decisions (scope, dev env, widget pattern). Numbered + dated. |

## Diagram rendering

Mermaid sources live inside the `.md` files. Pre-rendered PNGs in [`diagrams/`](diagrams/). To re-render:

```bash
npx --yes @mermaid-js/mermaid-cli -i docs/<file>.md -o docs/diagrams/<file>.png
```

## Reading order for first-time reader

1. **`01-concepts.md`** — what is DroneAid and why.
2. **`03-personas.docx`** — who uses it.
3. **`04-journey-map.md`** — how it feels to use.
4. **`07-software-architecture.md`** — how it is built.
5. **`08-implementation-diagram.md`** — how it actually runs.
6. **`09-page-flow-design.md`** — what every screen looks like + every flow's Gherkin AC. **This is what Claude Code reads to build the app.**
7. **`02-backlog-delphi.xlsx`** — what work it takes.
8. **`06-wbs.md`** — how the work breaks down.
9. **`05-gantt.xlsx`** — when it gets done.
10. **`00-team-raci.md`** — who does what.
11. **`adr/*.md`** — architecture decisions that shaped the plan (read after `00-team-raci.md`).

The full **design spec** in `superpowers/specs/` is the technical reference behind all of the above.
