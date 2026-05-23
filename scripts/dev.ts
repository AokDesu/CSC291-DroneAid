#!/usr/bin/env bun
// DroneAid — one-shot dev runner (Bun, cross-platform).
//
// Starts the Firebase Emulator Suite, waits for it to be ready, seeds it
// on first run, then runs the Flutter app. Ctrl-C tears everything down.
//
// Emulator state persists between runs in ./.emulator-data/.
//
// Usage:
//   bun scripts/dev.ts                    # uses the first available device
//   bun scripts/dev.ts -d <device-id>     # pass through to flutter run
//
// To wipe persisted emulator state and reseed from scratch:
//   rm -rf .emulator-data
//   bun scripts/dev.ts

import { existsSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { connect } from "node:net";

const REPO_ROOT = resolve(import.meta.dir, "..");
const APP_DIR = resolve(REPO_ROOT, "app");
const FUNCTIONS_DIR = resolve(REPO_ROOT, "functions");
const EMU_DATA = resolve(REPO_ROOT, ".emulator-data");
const FLUTTER_ARGS = process.argv.slice(2);

const FIRESTORE_PORT = 8080;
const AUTH_PORT = 9099;
const FUNCTIONS_PORT = 5001;
const UI_PORT = 4000;

const hasData = existsSync(EMU_DATA);
const env = { ...process.env, GCLOUD_PROJECT: "droneaid-csc291" };

console.log(`[dev] ${hasData ? "importing existing emulator data" : "first run; will seed and export on exit"}`);
console.log(`[dev] emulator UI will be at http://127.0.0.1:${UI_PORT}`);

// One-shot build so the emulator never loads stale lib/*.js. tsc is fast on
// this codebase (~1s) and avoids the "I edited a .ts but my callable didn't
// change" footgun.
console.log("[dev] building functions (tsc)…");
const buildOnce = Bun.spawn(["npm", "run", "build"], {
  cwd: FUNCTIONS_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
});
{
  const code = await buildOnce.exited;
  if (code !== 0) {
    console.error(`[dev] initial build failed (exit ${code})`);
    process.exit(code);
  }
}

// Background tsc --watch so any subsequent .ts edit triggers a recompile of
// lib/*.js. The Firebase functions emulator already watches lib/ and reloads
// on change, so this gives live-reload of Cloud Functions.
console.log("[dev] starting tsc --watch in background…");
const tscWatch = Bun.spawn(["npx", "tsc", "--watch", "--preserveWatchOutput"], {
  cwd: FUNCTIONS_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
});

const emuArgs = [
  "emulators:start",
  "--only", "auth,firestore,functions,ui",
  ...(hasData ? ["--import", EMU_DATA] : []),
  "--export-on-exit", EMU_DATA,
];

const emu = Bun.spawn(["firebase", ...emuArgs], {
  cwd: FUNCTIONS_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
  stdin: "inherit",
});

let shuttingDown = false;
const shutdown = async (code = 0) => {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log("\n[dev] shutting down…");
  try { tscWatch.kill("SIGTERM"); } catch {}
  try { emu.kill("SIGINT"); } catch {}
  await emu.exited;
  process.exit(code);
};

process.on("SIGINT", () => shutdown(0));
process.on("SIGTERM", () => shutdown(0));

const probePort = (port: number): Promise<boolean> =>
  new Promise((res) => {
    const sock = connect({ host: "127.0.0.1", port }, () => {
      sock.end();
      res(true);
    });
    sock.on("error", () => res(false));
    sock.setTimeout(800, () => { sock.destroy(); res(false); });
  });

const waitFor = async (port: number, label: string, timeoutMs = 60_000) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await probePort(port)) return;
    await Bun.sleep(500);
  }
  throw new Error(`Timed out waiting for ${label} on port ${port}`);
};

await Promise.all([
  waitFor(FIRESTORE_PORT, "firestore"),
  waitFor(AUTH_PORT, "auth"),
  waitFor(FUNCTIONS_PORT, "functions"),
]);
console.log("[dev] emulators up");

if (!hasData) {
  console.log("[dev] seeding…");
  // Call node directly against the already-compiled lib/ to skip npm-run-seed's
  // redundant `npm run build` (we built upfront + have tsc --watch keeping lib/
  // current). Avoids two tsc processes racing on the same output dir.
  const seed = Bun.spawn(["node", "lib/seed/seedAll.js"], {
    cwd: FUNCTIONS_DIR,
    env: {
      ...env,
      FIRESTORE_EMULATOR_HOST: `127.0.0.1:${FIRESTORE_PORT}`,
      FIREBASE_AUTH_EMULATOR_HOST: `127.0.0.1:${AUTH_PORT}`,
    },
    stdout: "inherit",
    stderr: "inherit",
  });
  const code = await seed.exited;
  if (code !== 0) {
    console.error(`[dev] seed failed (exit ${code})`);
    await shutdown(code);
  }
}

console.log("[dev] starting flutter run…");
const flutter = Bun.spawn(["flutter", "run", ...FLUTTER_ARGS], {
  cwd: APP_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
  stdin: "inherit",
});

const flutterCode = await flutter.exited;
await shutdown(flutterCode);
