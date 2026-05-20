<!--
Thanks for opening a PR. Fill the sections below before requesting review.
Refer to docs/superpowers/specs/2026-05-19-drone-relief-design.md §15 for the merge gate definition.
-->

## Summary

<!-- 1-3 bullets explaining the change. -->

## Linked work

<!-- Issue numbers, design-spec sections (§), page IDs (P-U-NN), flow IDs (F-NN). -->

## Type of change

- [ ] feat — new feature
- [ ] fix — bug fix
- [ ] docs — documentation only
- [ ] chore — repo plumbing, no behavior change
- [ ] test — tests only
- [ ] refactor — behavior preserved
- [ ] perf — performance

## Checklist

### Tests
- [ ] Unit / widget tests cover every Gherkin scenario for touched pages.
- [ ] Cloud Function tests cover every documented error code.
- [ ] If `firestore.rules` changed, rules unit tests updated.

### Security
- [ ] No direct client writes to `requests` / `flights` / `drones` / `notifications`.
- [ ] Every new callable validates `context.auth` and enforces role.
- [ ] No national ID / password / token logged.
- [ ] No secret in source (gitleaks clean).
- [ ] If rules loosened, the design spec is updated in the same PR.

### Docs
- [ ] If page contract changed, `docs/09-page-flow-design.md` updated.
- [ ] If schema changed, design spec §4 updated.
- [ ] If callable signature changed, design spec §10 updated.

### Agent-log discipline (class requirement)
- [ ] My Claude Code session JSONL for the work day is committed under `docs/agent-logs/<my-handle>/`.
- [ ] The log was redacted via `scripts/redact-secrets.py` (the SessionEnd hook does this automatically; verify).

### CI
- [ ] All required checks green.
- [ ] No `--no-verify` / `--no-gpg-sign` used.

## Screenshots / video

<!-- For UI changes, attach before/after. -->

## Notes for the reviewer

<!-- Anything reviewers should pay extra attention to. -->
