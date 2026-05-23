#!/usr/bin/env bash
# DroneAid — one-shot dev runner (Linux / macOS).
#
# Starts the Firebase Emulator Suite, seeds it, then runs the Flutter app.
# Ctrl-C tears everything down via `firebase emulators:exec`.
#
# Usage:
#   scripts/dev.sh                    # uses the first available device
#   scripts/dev.sh -d <device-id>     # pass through to flutter run

set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$repo_root/functions"

# Seed needs these — emulators:exec sets the host envs itself for the spawned
# child process, but the seed script also needs the project id.
export GCLOUD_PROJECT=droneaid-csc291

flutter_args="$*"

firebase emulators:exec \
  --only auth,firestore,functions \
  "npm run seed && cd \"$repo_root/app\" && flutter run $flutter_args"
