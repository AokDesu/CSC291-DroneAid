// Flight-mutation helpers reused across callables (recallFlight,
// setWeather storm cascade) and the scheduled tick. Kept tx-bound so
// callers compose their own validation + side-effects around it.
//
// See docs/adr/0005-recall-and-storm-evacuation.md.

import { Timestamp, type Transaction } from "firebase-admin/firestore";
import { db } from "./admin";

/**
 * Transition a flight from enroute or delivering into returning, and
 * mark its underlying Request as failed. The drone keeps its `flying`
 * status — the existing `returning` branch of `tickFlights` will land
 * it back at the base and flip it to `idle` on arrival.
 *
 * Caller is responsible for:
 *   - validating the flight currently allows the transition (status
 *     check) — this helper performs the writes unconditionally;
 *   - any FCM notifications outside the transaction.
 */
export function recallFlightTx(
  tx: Transaction,
  args: {
    flightId: string;
    droneId: string;
    requestId: string;
    nowMs: number;
    /// Drone battery at the moment of recall. The tick loop uses this as
    /// the starting battery for the return-trip snapshot so it doesn't
    /// re-credit the outbound-leg drain.
    batteryAtReturnStart: number;
  },
): void {
  const flightRef = db.doc(`flights/${args.flightId}`);
  const requestRef = db.doc(`requests/${args.requestId}`);
  tx.update(flightRef, {
    status: "returning",
    returningStartedAt: Timestamp.fromMillis(args.nowMs),
    batteryAtReturnStart: args.batteryAtReturnStart,
    recalled: true,
  });
  tx.update(requestRef, {
    status: "failed",
  });
}
