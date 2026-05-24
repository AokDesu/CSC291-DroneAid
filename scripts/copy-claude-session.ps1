# DroneAid — Claude Code SessionEnd hook (Windows / PowerShell).
#
# Copies the most-recently-modified Claude Code session JSONL for THIS project
# into docs/agent-logs/<your-handle>/, redacted of secrets via redact-secrets.py.
#
# Setup:
#   1. setx DRONE_AID_HANDLE aok       # one of: aok belle bew poom tawan
#      (reopen terminal so the new env var is picked up)
#   2. Add a SessionEnd hook to %USERPROFILE%\.claude\settings.json that calls
#      this script. See docs/agent-logs/README.md for the JSON snippet.
#
# Each run writes a new file (HHmmss suffix). Branches never collide on the same
# session id because every snapshot has a unique path. Old snapshots are strict
# subsets of newer ones (Claude appends within a session); harmless to keep.

$ErrorActionPreference = "Stop"

# Resolve repo root (the directory two levels above this script).
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Per-dev handle (folder name under docs/agent-logs).
$Handle = $env:DRONE_AID_HANDLE
if (-not $Handle) {
    Write-Error "DRONE_AID_HANDLE is not set. Run e.g. 'setx DRONE_AID_HANDLE aok' and reopen the terminal."
    exit 1
}

# Per-project Claude Code session directory. Claude Code encodes the absolute
# repo path by replacing each '/', '\', and ':' with '-'. So a clone at
# C:\Users\Belle\Projects\CSC291-DroneAid becomes
# C--Users-Belle-Projects-CSC291-DroneAid under %USERPROFILE%\.claude\projects.
$Encoded = ($RepoRoot -replace '[\\:/]', '-')
$SessionDir = Join-Path $env:USERPROFILE ".claude\projects\$Encoded"

# Fallback 1: legacy hard-coded encoding from the original template (kept for
# back-compat with anyone whose clone was already wired up to D:\projects\csc291).
if (-not (Test-Path $SessionDir)) {
    $Fallback = Join-Path $env:USERPROFILE ".claude\projects\D--projects-csc291"
    if (Test-Path $Fallback) { $SessionDir = $Fallback }
}

# Fallback 2: if neither path exists, glob the newest folder under
# .claude\projects\ whose name contains this repo's leaf directory. Handy for
# renamed clones (e.g. CSC291-DroneAid-belle-fork).
if (-not (Test-Path $SessionDir)) {
    $RepoLeaf = Split-Path $RepoRoot -Leaf
    $Candidate = Get-ChildItem -Path (Join-Path $env:USERPROFILE ".claude\projects") -Directory -ErrorAction SilentlyContinue `
        | Where-Object { $_.Name -like "*$RepoLeaf*" } `
        | Sort-Object LastWriteTime -Descending `
        | Select-Object -First 1
    if ($Candidate) { $SessionDir = $Candidate.FullName }
}

if (-not (Test-Path $SessionDir)) {
    Write-Host "No Claude Code session dir found for this clone."
    Write-Host "Looked under $env:USERPROFILE\.claude\projects\ for an encoded path matching $Encoded."
    exit 0
}

# Newest *.jsonl in that directory.
$Latest = Get-ChildItem -Path $SessionDir -Filter *.jsonl -File `
    | Sort-Object LastWriteTime -Descending `
    | Select-Object -First 1

if (-not $Latest) {
    Write-Host "No .jsonl session files found in $SessionDir."
    exit 0
}

# Resolve python (prefer py launcher on Windows).
$Py = (Get-Command py -ErrorAction SilentlyContinue)
if (-not $Py) { $Py = (Get-Command python -ErrorAction SilentlyContinue) }
if (-not $Py) {
    Write-Error "Python not found. Install Python 3.13 (or higher) and re-run."
    exit 1
}

# Target path under docs/agent-logs. Filename:
# YYYY-MM-DD_<sessionUUID>_HHmmss.jsonl — the HHmmss suffix gives every snapshot
# a unique path so two branches can each carry the same session id without
# colliding.
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "HHmmss"
$TargetDir = Join-Path $RepoRoot "docs\agent-logs\$Handle"
$TargetFile = Join-Path $TargetDir "$Date`_$($Latest.BaseName)`_$Time.jsonl"

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# Pipe through the redactor.
$Redactor = Join-Path $RepoRoot "scripts\redact-secrets.py"
Get-Content $Latest.FullName -Raw | & $Py.Source $Redactor | Out-File -Encoding utf8 -FilePath $TargetFile

Write-Host "Wrote: $TargetFile"
