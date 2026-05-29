// User-callable: file a delivery-issue report against own request.
// Writes a requests/{reqId}/reports/{auto-id} doc and fans an FCM
// notification out to all admins via sendToAdmins.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";
import { sendToAdmins } from "../lib/fcm";

const InputSchema = z.object({
  reqId: z.string().min(1),
  message: z.string().min(1).max(500),
});

export const reportDeliveryIssue = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { reqId, message } = parsed.data;

  const reqRef = db.doc(`requests/${reqId}`);
  const reportRef = reqRef.collection("reports").doc();

  await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqSnap.data() ?? {};
    if (r.userId !== uid) {
      throw new HttpsError("permission-denied", "Not your request.");
    }
    tx.set(reportRef, {
      uid,
      message,
      createdAt: Timestamp.now(),
      requestStatus: r.status,
      flightId: r.currentFlightId ?? null,
    });
  });

  // Outside the tx — failure to push must not roll back the report write.
  const preview = message.length <= 80 ? message : `${message.slice(0, 80)}…`;
  void sendToAdmins({
    title: "Delivery issue reported",
    body: preview,
    deepLink: `/admin/requests/${reqId}`,
    data: { type: "delivery_issue", requestId: reqId, reportId: reportRef.id },
  });

  return { ok: true, reportId: reportRef.id };
});
