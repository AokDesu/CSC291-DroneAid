// Admin-callable: dismiss an open Report without acting on it.
// See docs/adr/0004-reports-as-first-class-dispute-entity.md.
//
// Distinct from resolveReport: dismissal leaves the underlying Request
// status untouched. The note is required and surfaces to the user so they
// know they were heard but the answer was "no."

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { sendToUser } from "../lib/fcm";

const InputSchema = z.object({
  reqId: z.string().min(1),
  reportId: z.string().min(1),
  note: z.string().min(1).max(500),
});

export const dismissReport = onCall(async (req) => {
  const { uid: adminUid } = await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { reqId, reportId, note } = parsed.data;

  const reqRef = db.doc(`requests/${reqId}`);
  const reportRef = reqRef.collection("reports").doc(reportId);

  const ownerUid = await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const reportSnap = await tx.get(reportRef);
    if (!reportSnap.exists) throw new HttpsError("not-found", "Report not found.");

    const reportData = reportSnap.data() ?? {};
    if (reportData.status !== "open") {
      throw new HttpsError(
        "failed-precondition",
        `Cannot dismiss a ${reportData.status} report.`,
      );
    }

    tx.update(reportRef, {
      status: "dismissed",
      resolutionNote: note,
      resolvedBy: adminUid,
      resolvedAt: Timestamp.now(),
    });

    return reqSnap.data()?.userId as string;
  });

  void sendToUser(ownerUid, {
    title: "Report dismissed",
    body: note,
    deepLink: `/user/history`,
    data: { type: "report_dismissed", requestId: reqId, reportId },
  });

  return { ok: true };
});
