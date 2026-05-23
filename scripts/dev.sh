#!/usr/bin/env bash
# DroneAid — one-shot dev runner (Linux / macOS).
#
# Starts the Firebase Emulator Suite, seeds it on first run, then runs the
# Flutter app. Emulator state persists between runs in ./.emulator-data/.
# Ctrl-C tears everything down via `firebase emulators:exec`.
#
# Usage:
#   scripts/dev.sh                    # uses the first available device
#   scripts/dev.sh -d <device-id>     # pass through to flutter run
#
# To wipe persisted emulator state and reseed from scratch:
#   rm -rf .emulator-data
#   scripts/dev.sh

set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
emu_data="$repo_root/.emulator-data"

cd "$repo_root/functions"

# Seed needs the project id; the emulator hosts are injected by emulators:exec.
export GCLOUD_PROJECT=droneaid-csc291

flutter_args="$*"

if [[ -d "$emu_data" ]]; then
  echo "[dev] importing existing emulator data from $emu_data"
  firebase emulators:exec \
    --only auth,firestore,functions \
    --import="$emu_data" \
    --export-on-exit="$emu_data" \
    "cd \"$repo_root/app\" && flutter run $flutter_args"
else
  echo "[dev] no $emu_data — first run, will seed and export on exit"
  firebase emulators:exec \
    --only auth,firestore,functions \
    --export-on-exit="$emu_data" \
    "npm run seed && cd \"$repo_root/app\" && flutter run $flutter_args"
fi
