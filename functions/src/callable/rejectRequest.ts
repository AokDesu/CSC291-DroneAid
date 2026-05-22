// Admin-callable: reject a pending request with a reason.
// Spec: §10 rejectRequest, flow F-17.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { sendToUser } from "../lib/fcm";

const InputSchema = z.object({
  reqId: z.string().min(1),
  reason: z.string().min(1).max(200),
});

export const rejectRequest = onCall(async (req) => {
  const { uid: adminUid } = await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const ref = db.doc(`requests/${parsed.data.reqId}`);
  const userId = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = snap.data() ?? {};
    if (r.status !== "pending") {
      throw new HttpsError("failed-precondition", `Cannot reject a ${r.status} request.`);
    }
    tx.update(ref, {
      status: "rejected",
      decidedBy: adminUid,
      decidedAt: Timestamp.now(),
      rejectReason: parsed.data.reason,
    });
    return r.userId as string;
  });

  void sendToUser(userId, {
    title: "Request rejected",
    body: parsed.data.reason,
    deepLink: `/user/history`,
    data: { type: "request_rejected", requestId: parsed.data.reqId },
  });

  return { ok: true };
});
