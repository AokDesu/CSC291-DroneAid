# CSC291-DroneAid

> Class project on the Firebase Emulator Suite. Deadline 2026-06-04; submission 2026-06-05. No real Firebase deploy (see `docs/adr/0002-scope-full-features-fcm-emulator-exempt.md`).

## Running the stack

Single command for the full stack (emulators + seed on first run + Flutter app):

```bash
bun scripts/dev.ts
```

State persists in gitignored `./.emulator-data/` between runs. See README "Daily run loop" for prerequisites + the wipe-and-reseed escape hatch.

## Working an issue

22 issues attached to milestone **"2026-06-04 submission"** (#9-#30). Standard per-dev flow:

```bash
gh issue list --assignee @me --state open --milestone "2026-06-04 submission"
gh issue view <number> --comments
git checkout -b feat/<short>
# ...implement per the issue body's AC...
gh pr create --base main --body "Closes #<number>\n\n..."
```

Issue bodies contain: spec link, acceptance criteria, files to touch, blockers (`Blocked by #N`), test plan. Honour blockers — many consumer pages are gated on Belle's widget API stubs (#23) per `docs/adr/0003-widget-api-stub-first.md`.

## Architecture decisions

`docs/adr/` records hard-to-reverse decisions:

- **0001** — Native Windows is the dev-env standard for non-lead devs.
- **0002** — "Done" means full features on the emulator; FCM-push-to-device is exempt.
- **0003** — Belle ships widget API stubs Day 4 (frozen public API) so consumers can start in parallel.

## Agent skills

### Issue tracker

Issues live in GitHub Issues at `AokDesu/CSC291-DroneAid`, accessed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical vocabulary (created in the repo): `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Domain labels: `auth`, `request`, `tracking`, `fleet`, `widget`, `infra`, `demo`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` (not created yet — `/grill-with-docs` creates it lazily when a domain term is first disambiguated) + `docs/adr/` at repo root. See `docs/agents/domain.md`.
