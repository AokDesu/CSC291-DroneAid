#!/usr/bin/env bun
// DroneAid — one-shot dev runner (Bun, cross-platform).
//
// Starts the Firebase Emulator Suite, waits for it to be ready, seeds it
// on first run, then runs the Flutter app. Ctrl-C tears everything down and
// persists emulator state; quitting Flutter (q) also persists state.
//
// Emulator state persists between runs in ./.emulator-data/.
//
// Usage:
//   bun scripts/dev.ts                    # uses the first available device
//   bun scripts/dev.ts -d <device-id>     # pass through to flutter run
//
// To wipe persisted emulator state and reseed from scratch:
//   rm -rf .emulator-data                          # macOS/Linux
//   Remove-Item -Recurse -Force .emulator-data     # Windows PowerShell
//   bun scripts/dev.ts

import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { connect } from "node:net";

const REPO_ROOT = resolve(import.meta.dir, "..");
const APP_DIR = resolve(REPO_ROOT, "app");
const FUNCTIONS_DIR = resolve(REPO_ROOT, "functions");
const EMU_DATA = resolve(REPO_ROOT, ".emulator-data");
const FLUTTER_ARGS = process.argv.slice(2);

// Windows ships npm/npx/firebase/flutter as .cmd shims; Bun.spawn won't resolve
// the bare name. node.exe / taskkill.exe are real executables on PATH, so they
// stay as-is.
const IS_WIN = process.platform === "win32";
const bin = (name: string) => (IS_WIN ? `${name}.cmd` : name);

const FIRESTORE_PORT = 8080;
const AUTH_PORT = 9099;
const FUNCTIONS_PORT = 5001;
const UI_PORT = 4000;

// On Windows the .cmd shims run through cmd.exe, whose argument quoting is
// fragile. A repo cloned under a path with spaces (e.g. "C:\Users\Jane Doe\…")
// can make the firebase --import/--export paths break in non-obvious ways.
// Warn loudly rather than fail mysteriously.
if (IS_WIN && EMU_DATA.includes(" ")) {
  console.warn(
    `[dev] WARNING: repo path contains spaces:\n` +
      `        ${EMU_DATA}\n` +
      `        Firebase --import/--export may misbehave on Windows.\n` +
      `        Consider cloning to a space-free path (e.g. C:\\src\\droneaid).`,
  );
}

const hasData = existsSync(EMU_DATA);
const env = { ...process.env, GCLOUD_PROJECT: "droneaid-csc291" };

console.log(`[dev] ${hasData ? "importing existing emulator data" : "first run; will seed and export on exit"}`);
console.log(`[dev] emulator UI will be at http://127.0.0.1:${UI_PORT}`);

// One-shot build so the emulator never loads stale lib/*.js. tsc is fast on
// this codebase (~1s) and avoids the "I edited a .ts but my callable didn't
// change" footgun.
console.log("[dev] building functions (tsc)…");
const buildOnce = Bun.spawn([bin("npm"), "run", "build"], {
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
const tscWatch = Bun.spawn([bin("npx"), "tsc", "--watch", "--preserveWatchOutput"], {
  cwd: FUNCTIONS_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
});

const emuArgs = [
  "emulators:start",
  "--only", "auth,firestore,functions,ui",
  ...(hasData ? ["--import", EMU_DATA] : []),
  // Safety net for the Ctrl-C path (see shutdown()): on a console signal the
  // emulator exports on its own. We never rely on this for the flutter-quit
  // path — that uses an explicit emulators:export instead.
  "--export-on-exit", EMU_DATA,
];

const emu = Bun.spawn([bin("firebase"), ...emuArgs], {
  cwd: FUNCTIONS_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
  stdin: "inherit",
});

// ---------------------------------------------------------------------------
// Shutdown helpers
// ---------------------------------------------------------------------------

// Force-terminate a process tree. The named tools are launched on Windows via
// cmd.exe wrappers, so /T is required to reach the real child (the Java
// firestore/auth emulators, the tsc node process). Last-resort only — it does
// NOT let the emulator run its export hook.
const forceKill = (pid: number) => {
  if (IS_WIN) {
    try { Bun.spawnSync(["taskkill", "/pid", String(pid), "/T", "/F"]); } catch {}
  } else {
    try { process.kill(pid, "SIGKILL"); } catch {}
  }
};

// Race a process's exit against a timeout. Returns true if it exited in time.
const exitedWithin = async (proc: { exited: Promise<number> }, ms: number) => {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<boolean>((r) => { timer = setTimeout(() => r(false), ms); });
  const done = proc.exited.then(() => true);
  const ok = await Promise.race([done, timeout]);
  clearTimeout(timer!);
  return ok;
};

// Ask the *running* emulator to dump its state to disk, deterministically.
// Used on the flutter-quit path, where no console Ctrl-C reaches the emulator
// and so --export-on-exit would never fire. --force overwrites the existing
// export dir without an interactive prompt (which would hang on inherited
// stdin). Tolerant of failure: if the emulator is already going down (e.g. a
// racing signal), we just warn and let the caller stop it.
const exportEmulatorData = async () => {
  try {
    const exp = Bun.spawn([bin("firebase"), "emulators:export", EMU_DATA, "--force"], {
      cwd: FUNCTIONS_DIR,
      env,
      stdout: "inherit",
      stderr: "inherit",
      stdin: "ignore",
    });
    if (!(await exitedWithin(exp, 30_000))) {
      forceKill(exp.pid);
      console.warn("[dev] emulator export timed out");
    } else if ((await exp.exited) !== 0) {
      console.warn("[dev] emulator export reported a non-zero exit");
    }
  } catch (e) {
    console.warn(`[dev] emulator export failed: ${e}`);
  }
};

let shuttingDown = false;
let gotSignal = false;

// reason:
//   "signal"       → user pressed Ctrl-C. On Windows the OS already delivered
//                    CTRL_C_EVENT to the emulator (it shares our console), so
//                    it is already exporting + exiting. We must NOT race it
//                    with taskkill — we wait for the graceful export to finish
//                    and only force-kill if it hangs. On Unix we send SIGINT
//                    ourselves for the same effect.
//   "flutter-exit" → user quit Flutter (q) or it crashed. No console signal
//                    reached the emulator, so --export-on-exit would never
//                    fire. We trigger an explicit export, THEN stop it.
//   "abort"        → early failure (e.g. seed failed) on a fresh run. Do NOT
//                    export — the on-disk state would be incomplete/garbage and
//                    would poison the next --import. Hard-stop everything.
const shutdown = async (code = 0, reason: "signal" | "flutter-exit" | "abort" = "signal") => {
  if (shuttingDown) return;
  shuttingDown = true;
  // A racing Ctrl-C always wins: if a signal was seen, treat as graceful export.
  if (gotSignal && reason === "flutter-exit") reason = "signal";

  console.log(`\n[dev] shutting down (${reason})…`);

  // tsc --watch has no state to flush; stop it immediately on every path.
  if (IS_WIN) forceKill(tscWatch.pid);
  else { try { tscWatch.kill("SIGTERM"); } catch {} }

  if (reason === "abort") {
    // SIGKILL / taskkill /F deliberately skips the export hook.
    forceKill(emu.pid);
    await emu.exited;
    process.exit(code);
  }

  if (reason === "flutter-exit") {
    // Emulator is still fully alive and got no signal — export on demand,
    // then stop it (data is safely on disk, so a force stop is fine).
    console.log("[dev] exporting emulator state…");
    await exportEmulatorData();
    if (IS_WIN) forceKill(emu.pid);
    else { try { emu.kill("SIGINT"); } catch {} }
    if (!(await exitedWithin(emu, 15_000))) forceKill(emu.pid);
    await emu.exited;
    process.exit(code);
  }

  // reason === "signal": let the signal-driven export run to completion.
  // On Windows the emulator already received CTRL_C_EVENT from the console;
  // on Unix we deliver SIGINT here.
  if (!IS_WIN) { try { emu.kill("SIGINT"); } catch {} }
  console.log("[dev] waiting for emulator to export and exit…");
  if (!(await exitedWithin(emu, 30_000))) {
    console.warn("[dev] emulator didn't exit in time; forcing.");
    forceKill(emu.pid);
    await emu.exited;
  }
  process.exit(code);
};

process.on("SIGINT", () => { gotSignal = true; void shutdown(0, "signal"); });
process.on("SIGTERM", () => { gotSignal = true; void shutdown(0, "signal"); });

// ---------------------------------------------------------------------------
// Readiness probing
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// First-run seed
// ---------------------------------------------------------------------------

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
    await shutdown(code, "abort");
  }
}

// ---------------------------------------------------------------------------
// Flutter
// ---------------------------------------------------------------------------

console.log("[dev] starting flutter run…");
const flutter = Bun.spawn([bin("flutter"), "run", ...FLUTTER_ARGS], {
  cwd: APP_DIR,
  env,
  stdout: "inherit",
  stderr: "inherit",
  stdin: "inherit",
});

const flutterCode = await flutter.exited;
// If Ctrl-C drove us here, gotSignal is set and shutdown() will promote this to
// the "signal" path; otherwise the user quit Flutter and we export explicitly.
await shutdown(flutterCode, "flutter-exit");
