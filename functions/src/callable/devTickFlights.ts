// Dev-only callable that advances every active flight by one tick.
//
// Why this exists: the `tickFlights` scheduled function (every 1 min) does
// not fire under the Firebase emulator because there is no pub/sub emulator.
// Without it, flight statuses never transition past `enroute` and the demo
// gets stuck. This callable wraps the same `tickAllFlights` body so an admin
// can hit "Tick now" on the Control page during demos.
//
// Hard-gated to emulator-only via FUNCTIONS_EMULATOR (set by the Firebase
// emulator runtime). Per ADR-0002 we do not deploy to prod, but defence in
// depth — this must never run against a real Firestore.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireUser } from "../lib/roles";
import { tickAllFlights } from "../scheduled/tickFlights";

export const devTickFlights = onCall(async (req) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError(
      "permission-denied",
      "devTickFlights is only available on the Firebase emulator.",
    );
  }
  // Any signed-in tester (admin OR end-user) can drive the loop locally —
  // the env gate above already prevents prod calls. Lets the demo flight
  // progress while testing the user-side flow without parking on
  // /admin/control. requireUser keeps the call rejected when no auth token
  // is attached at all.
  await requireUser(req);
  return tickAllFlights(Date.now());
});
