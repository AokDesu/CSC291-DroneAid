# DroneAid — one-shot dev runner (Windows PowerShell).
#
# Starts the Firebase Emulator Suite, seeds it, then runs the Flutter app.
# Ctrl-C tears everything down via `firebase emulators:exec`.
#
# Usage:
#   .\scripts\dev.ps1                    # uses the first available device
#   .\scripts\dev.ps1 -d <device-id>     # pass through to flutter run

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location -Path "$repoRoot\functions"

# Seed needs these — emulators:exec sets the host envs itself for the spawned
# child process, but the seed script also needs the project id.
$env:GCLOUD_PROJECT = 'droneaid-csc291'

$flutterArgs = $args -join ' '

firebase emulators:exec `
  --only auth,firestore,functions `
  "npm run seed && cd `"$repoRoot\app`" && flutter run $flutterArgs"
