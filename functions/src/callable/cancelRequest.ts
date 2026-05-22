// User-callable: cancel own request while still in status "pending".
// Spec: §10 cancelRequest, flow F-09.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";

const InputSchema = z.object({ reqId: z.string().min(1) });

export const cancelRequest = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const ref = db.doc(`requests/${parsed.data.reqId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Request not found.");
    const data = snap.data() ?? {};
    if (data.userId !== uid) throw new HttpsError("permission-denied", "Not your request.");
    if (data.status !== "pending") {
      throw new HttpsError("failed-precondition", `Cannot cancel a ${data.status} request.`);
    }
    tx.update(ref, { status: "cancelled", decidedAt: Timestamp.now() });
  });
  return { ok: true };
});
