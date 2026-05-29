// Admin-callable: register a new drone in the fleet.
// Auto-generates a sequential `drn-NNN` id by scanning the existing fleet
// inside the transaction so concurrent creates don't collide.
// New drones start at status='idle', batteryPct=100, no currentFlight.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  name: z.string().min(1).max(40),
  maxPayloadKg: z.number().positive().max(10),
  baseLocation: z.object({
    lat: z.number().gte(-90).lte(90),
    lng: z.number().gte(-180).lte(180),
  }),
});

export const createDrone = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }

  const id = await db.runTransaction(async (tx) => {
    const all = await tx.get(db.collection("drones"));
    let max = 0;
    for (const d of all.docs) {
      const m = d.id.match(/^drn-(\d+)$/);
      if (m) {
        max = Math.max(max, parseInt(m[1], 10));
      }
    }
    const nextId = `drn-${String(max + 1).padStart(3, "0")}`;
    tx.set(db.doc(`drones/${nextId}`), {
      name: parsed.data.name,
      status: "idle",
      batteryPct: 100,
      baseLocation: parsed.data.baseLocation,
      maxPayloadKg: parsed.data.maxPayloadKg,
      currentFlightId: null,
      lastSeenAt: FieldValue.serverTimestamp(),
    });
    return nextId;
  });

  return { ok: true, droneId: id };
});
