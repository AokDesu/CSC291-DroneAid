# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Working an issue (per-dev workflow)

For team members picking up an issue from the "2026-06-04 submission" milestone (issues #9-#30 as of 2026-05-23):

```bash
# 1. Authenticate once per machine (each dev as themselves):
gh auth login

# 2. List your assigned, open issues:
gh issue list --assignee @me --state open --milestone "2026-06-04 submission"

# 3. Pick one and read it:
gh issue view <number> --comments

# 4. Branch + implement (typical branch name: feat/<page-id>-<short>):
git checkout main && git pull --ff-only
git checkout -b feat/p-a-01-admin-requests

# 5. Open the PR with auto-close link to the issue:
gh pr create --base main --title "..." --body "Closes #<number>\n\n..."
```

`Closes #N` (or `Fixes #N` / `Resolves #N`) in the PR body auto-closes the issue when the PR merges.

## Blockers

Several issues have `Blocked by #N` in their body (e.g. consumer pages blocked by Belle's widget API stubs #23 per ADR-0003). Don't start a blocked issue until the dependency PR is merged. Use `gh issue view <N>` to check current status of the blocker.

## Repo membership

GitHub assignment only sticks for users with at least read access on the repo. Lead invites teammates as collaborators via `gh api repos/<owner>/<repo>/collaborators/<handle> -X PUT -f permission=push` (or the Settings → Manage access UI). Issue body still says "Owner: @handle" even before the invite is accepted, so the intent is preserved.
