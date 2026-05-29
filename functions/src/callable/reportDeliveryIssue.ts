// User-callable: file a delivery-issue report against own request.
// Writes a requests/{reqId}/reports/{auto-id} doc and fans an FCM
// notification out to all admins via sendToAdmins.
//
// Lifecycle (see docs/adr/0004-reports-as-first-class-dispute-entity.md):
//   - Filable only when Request status ∈ {delivered, confirmed, failed}.
//   - Only one `open` Report per Request at a time.
//   - Resolution happens via resolveReport / dismissReport admin callables.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";
import { sendToAdmins } from "../lib/fcm";

const InputSchema = z.object({
  reqId: z.string().min(1),
  message: z.string().min(1).max(500),
});

const FILABLE_REQUEST_STATUSES = new Set(["delivered", "confirmed", "failed"]);

export const reportDeliveryIssue = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { reqId, message } = parsed.data;

  const reqRef = db.doc(`requests/${reqId}`);
  const reportsCol = reqRef.collection("reports");
  const reportRef = reportsCol.doc();

  await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqSnap.data() ?? {};
    if (r.userId !== uid) {
      throw new HttpsError("permission-denied", "Not your request.");
    }
    if (!FILABLE_REQUEST_STATUSES.has(r.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot report a ${r.status} request.`,
      );
    }

    const openSnap = await tx.get(reportsCol.where("status", "==", "open").limit(1));
    if (!openSnap.empty) {
      throw new HttpsError(
        "failed-precondition",
        "An open report already exists on this request.",
      );
    }

    tx.set(reportRef, {
      uid,
      message,
      status: "open",
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
    deepLink: `/admin/reports`,
    data: { type: "delivery_issue", requestId: reqId, reportId: reportRef.id },
  });

  return { ok: true, reportId: reportRef.id };
});
