// Admin-callable: edit a drone's `name`, `maxPayloadKg`, or `baseLocation`.
// status / batteryPct / currentFlightId stay under the control of their
// own callables (toggleDroneMaintenance, assignDrone, tickFlights).
// Refuses while the drone is mid-flight.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  droneId: z.string().min(1),
  name: z.string().min(1).max(40).optional(),
  maxPayloadKg: z.number().positive().max(10).optional(),
  baseLocation: z
    .object({
      lat: z.number().gte(-90).lte(90),
      lng: z.number().gte(-180).lte(180),
    })
    .optional(),
});

export const editDrone = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { droneId, ...changes } = parsed.data;

  if (Object.keys(changes).length === 0) {
    throw new HttpsError("invalid-argument", "Nothing to update.");
  }

  const ref = db.doc(`drones/${droneId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Drone not found.");
    const d = snap.data() ?? {};
    if (d.status === "flying") {
      throw new HttpsError(
        "failed-precondition",
        "Drone is flying. Wait until it lands.",
      );
    }
    tx.update(ref, changes);
  });

  return { ok: true };
});
