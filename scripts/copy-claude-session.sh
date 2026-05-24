#!/usr/bin/env bash
# DroneAid — Claude Code SessionEnd hook (POSIX shell).
#
# Copies the most-recently-modified Claude Code session JSONL for THIS project
# into docs/agent-logs/<your-handle>/, redacted of secrets via redact-secrets.py.
#
# Setup:
#   1. export DRONE_AID_HANDLE=aok        # one of: aok belle bew poom tawan
#   2. Add a SessionEnd hook to ~/.claude/settings.json that calls this script.
#
# Each run writes a new file (HHMMSS suffix). Branches never collide on the same
# session id because every snapshot has a unique path. Old snapshots are strict
# subsets of newer ones (Claude appends within a session); harmless to keep.

set -euo pipefail

# Resolve repo root (the directory two levels above this script).
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
repo_root="$( cd "$script_dir/.." && pwd )"

# Per-dev handle.
handle="${DRONE_AID_HANDLE:-}"
if [[ -z "$handle" ]]; then
  echo "DRONE_AID_HANDLE is not set. Add e.g. 'export DRONE_AID_HANDLE=aok' to your shell rc file." >&2
  exit 1
fi

# Per-project Claude Code session directory.
# Adjust the encoded path on your platform if the repo lives elsewhere.
session_dir="$HOME/.claude/projects/$(pwd | sed 's|^/||; s|/|-|g; s|^|-|')"
# Fallback to the Windows-style encoding used in this template.
[[ -d "$session_dir" ]] || session_dir="$HOME/.claude/projects/D--projects-csc291"

if [[ ! -d "$session_dir" ]]; then
  echo "No Claude Code session dir at $session_dir — nothing to copy."
  exit 0
fi

# Newest *.jsonl in that directory.
latest="$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -n1 || true)"
if [[ -z "$latest" ]]; then
  echo "No .jsonl session files found in $session_dir."
  exit 0
fi

# Resolve python.
py="$(command -v python3 || command -v python || true)"
if [[ -z "$py" ]]; then
  echo "Python not found. Install Python 3.13 (or higher) and re-run." >&2
  exit 1
fi

# Target path. Filename: YYYY-MM-DD_<sessionUUID>_HHMMSS.jsonl — the HHMMSS
# suffix gives every snapshot a unique path so two branches can each carry the
# same session id without colliding.
date_str="$(date +%Y-%m-%d)"
time_str="$(date +%H%M%S)"
target_dir="$repo_root/docs/agent-logs/$handle"
mkdir -p "$target_dir"

base="$(basename "$latest" .jsonl)"
target_file="$target_dir/${date_str}_${base}_${time_str}.jsonl"

# Pipe through the redactor.
"$py" "$repo_root/scripts/redact-secrets.py" < "$latest" > "$target_file"

echo "Wrote: $target_file"
