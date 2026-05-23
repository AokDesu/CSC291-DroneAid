# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Domain labels (also created in the repo)

Layered alongside the triage labels for filtering:

| Label | Use for |
|---|---|
| `auth` | Identity / login / register / role guard |
| `request` | Request domain (catalog, queue, history, admin requests, inventory) |
| `tracking` | Tracking, maps, FCM, notifications, control map |
| `fleet` | Drone fleet (list, detail, weather) |
| `widget` | Shared UI widgets |
| `infra` | Backend, build, CI, scripts, ops |
| `demo` | Demo prep (seed dataset, screenshots, screencast) |

Useful filter combos:

```bash
gh issue list --label "ready-for-agent,widget"     # widgets ready to start
gh issue list --label "ready-for-agent,tracking"   # tracking work
gh issue list --label "ready-for-human"            # needs human (e.g. demo screencast)
```
