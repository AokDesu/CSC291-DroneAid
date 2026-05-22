// Admin-callable: toggle a drone into / out of maintenance OR offline.
// Refuses to act on a drone whose status is "flying".
// Spec: §10 toggleDroneMaintenance, flow F-25.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  droneId: z.string().min(1),
  mode: z.enum(["idle", "maintenance", "offline"]),
});

export const toggleDroneMaintenance = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const ref = db.doc(`drones/${parsed.data.droneId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Drone not found.");
    const d = snap.data() ?? {};
    if (d.status === "flying") {
      throw new HttpsError("failed-precondition", "Drone is flying. Wait until it lands.");
    }
    tx.update(ref, { status: parsed.data.mode });
  });

  return { ok: true };
});
