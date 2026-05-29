// Admin-callable: force-land a drone whose flight is in the `returning`
// state. The simulated return trip takes the same real-time as the
// outbound leg (haversine distance / effective speed), which is too
// long to wait through a class demo. `collectDrone` short-circuits the
// simulation: completes the flight, parks the drone in `maintenance`
// for inspection / recharge, and subtracts the realistic round-trip
// battery drain.
//
// Restricted to `returning` flights — recallFlight already handles
// enroute/delivering. tickFlights still completes returns naturally
// when this is not invoked.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { haversineKm } from "../lib/geo";

const InputSchema = z.object({
  droneId: z.string().min(1),
});

const BATTERY_DRAIN_PER_KM = 1.5;

export const collectDrone = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }

  const droneRef = db.doc(`drones/${parsed.data.droneId}`);

  await db.runTransaction(async (tx) => {
    const droneSnap = await tx.get(droneRef);
    if (!droneSnap.exists) {
      throw new HttpsError("not-found", "Drone not found.");
    }
    const d = droneSnap.data() ?? {};
    if (d.status !== "flying") {
      throw new HttpsError(
        "failed-precondition",
        `Drone is ${d.status}, not flying.`,
      );
    }
    const flightId = d.currentFlightId as string | undefined;
    if (!flightId) {
      throw new HttpsError(
        "failed-precondition",
        "Drone has no linked flight.",
      );
    }
    const flightRef = db.doc(`flights/${flightId}`);
    const flightSnap = await tx.get(flightRef);
    if (!flightSnap.exists) {
      throw new HttpsError("not-found", "Linked flight not found.");
    }
    const f = flightSnap.data() ?? {};
    if (f.status !== "returning") {
      throw new HttpsError(
        "failed-precondition",
        `Flight is ${f.status}, not returning. Use recallFlight first if mid-outbound.`,
      );
    }

    const origin = f.origin as { lat: number; lng: number };
    const destination = f.destination as { lat: number; lng: number };
    const distKm = haversineKm(origin, destination);
    const batteryAtTakeoff = (f.batteryAtTakeoff as number | undefined) ?? 100;
    const roundTripDrain = 2 * distKm * BATTERY_DRAIN_PER_KM;
    const finalBattery = Math.max(0, Math.floor(batteryAtTakeoff - roundTripDrain));

    tx.update(flightRef, {
      status: "completed",
      archived: true,
      collected: true,
    });
    tx.update(droneRef, {
      status: "maintenance",
      currentFlightId: null,
      batteryPct: finalBattery,
    });
  });

  return { ok: true };
});
