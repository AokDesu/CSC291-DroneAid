# DroneAid — one-shot dev runner (Windows PowerShell).
#
# Starts the Firebase Emulator Suite, seeds it on first run, then runs the
# Flutter app. Emulator state persists between runs in .\.emulator-data\.
# Ctrl-C tears everything down via `firebase emulators:exec`.
#
# Usage:
#   .\scripts\dev.ps1                    # uses the first available device
#   .\scripts\dev.ps1 -d <device-id>     # pass through to flutter run
#
# To wipe persisted emulator state and reseed from scratch:
#   Remove-Item -Recurse -Force .\.emulator-data
#   .\scripts\dev.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$emuData  = Join-Path $repoRoot '.emulator-data'

Set-Location -Path (Join-Path $repoRoot 'functions')

# Seed needs the project id; the emulator hosts are injected by emulators:exec.
$env:GCLOUD_PROJECT = 'droneaid-csc291'

$flutterArgs = $args -join ' '
$appDir = Join-Path $repoRoot 'app'

if (Test-Path -Path $emuData) {
  Write-Host "[dev] importing existing emulator data from $emuData"
  firebase emulators:exec `
    --only auth,firestore,functions `
    --import="$emuData" `
    --export-on-exit `
    "cd `"$appDir`" && flutter run $flutterArgs"
} else {
  Write-Host "[dev] no $emuData - first run, will seed and export on exit"
  firebase emulators:exec `
    --only auth,firestore,functions `
    --export-on-exit="$emuData" `
    "npm run seed && cd `"$appDir`" && flutter run $flutterArgs"
}
