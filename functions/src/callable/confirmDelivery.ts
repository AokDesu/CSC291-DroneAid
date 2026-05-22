// User-callable: confirm receipt of a delivered request.
// Spec: §10 confirmDelivery, flow F-13.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";
import { sendToUser } from "../lib/fcm";

const InputSchema = z.object({ reqId: z.string().min(1) });

export const confirmDelivery = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const reqRef = db.doc(`requests/${parsed.data.reqId}`);
  await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqSnap.data() ?? {};
    if (r.userId !== uid) throw new HttpsError("permission-denied", "Not your request.");
    if (r.status === "confirmed") return; // idempotent
    if (r.status !== "delivered") {
      throw new HttpsError("failed-precondition", `Cannot confirm a ${r.status} request.`);
    }
    tx.update(reqRef, { status: "confirmed", decidedAt: Timestamp.now() });

    // Transition the linked flight to returning so the next tick brings the drone home.
    if (r.currentFlightId) {
      const flightRef = db.doc(`flights/${r.currentFlightId}`);
      const flightSnap = await tx.get(flightRef);
      if (flightSnap.exists) {
        tx.update(flightRef, { status: "returning", returningStartedAt: Timestamp.now() });
      }
    }
  });

  void sendToUser(uid, {
    title: "Delivery confirmed",
    body: "Thanks — your drone is heading home.",
    deepLink: `/user/history`,
    data: { type: "delivery_confirmed", requestId: parsed.data.reqId },
  });

  return { ok: true };
});
