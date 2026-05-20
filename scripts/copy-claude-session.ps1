# DroneAid — Claude Code SessionEnd hook (Windows / PowerShell).
#
# Copies the most-recently-modified Claude Code session JSONL for THIS project
# into docs/agent-logs/<your-handle>/, redacted of secrets via redact-secrets.py.
#
# Setup:
#   1. setx DRONE_AID_HANDLE aok       # one of: aok belle bew poom tawan
#   2. Add a SessionEnd hook to ~/.claude/settings.json that calls this script.
#
# Idempotent — running twice on the same session overwrites the same target file.

$ErrorActionPreference = "Stop"

# Resolve repo root (the directory two levels above this script).
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

# Per-dev handle (folder name under docs/agent-logs).
$Handle = $env:DRONE_AID_HANDLE
if (-not $Handle) {
    Write-Error "DRONE_AID_HANDLE is not set. Run e.g. 'setx DRONE_AID_HANDLE aok' and reopen the terminal."
    exit 1
}

# Per-project Claude Code session directory.
# The project path D:\projects\csc291 is encoded as 'D--projects-csc291' by Claude Code.
$ProjectDirEncoded = "D--projects-csc291"
$SessionDir = Join-Path $env:USERPROFILE ".claude\projects\$ProjectDirEncoded"

if (-not (Test-Path $SessionDir)) {
    Write-Host "No Claude Code session dir at $SessionDir — nothing to copy."
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

# Target path under docs/agent-logs.
$Date = Get-Date -Format "yyyy-MM-dd"
$TargetDir = Join-Path $RepoRoot "docs\agent-logs\$Handle"
$TargetFile = Join-Path $TargetDir "$Date`_$($Latest.BaseName).jsonl"

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# Pipe through the redactor.
$Redactor = Join-Path $RepoRoot "scripts\redact-secrets.py"
Get-Content $Latest.FullName -Raw | & $Py.Source $Redactor | Out-File -Encoding utf8 -FilePath $TargetFile

Write-Host "Wrote: $TargetFile"
