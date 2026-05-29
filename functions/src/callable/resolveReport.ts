// Admin-callable: resolve an open Report in the user's favour.
// See docs/adr/0004-reports-as-first-class-dispute-entity.md.
//
// Two outcomes the admin must pick from:
//   - confirm_with_remedy → Request → confirmed (delivery accepted with remedy)
//   - fail_delivery      → Request → failed    (delivery never effectively happened)
//
// The note is required and surfaces to the user in the resulting notification.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { sendToUser } from "../lib/fcm";

const OUTCOME_TO_REQUEST_STATUS = {
  confirm_with_remedy: "confirmed",
  fail_delivery: "failed",
} as const;

const InputSchema = z.object({
  reqId: z.string().min(1),
  reportId: z.string().min(1),
  outcome: z.enum(["confirm_with_remedy", "fail_delivery"]),
  note: z.string().min(1).max(500),
});

export const resolveReport = onCall(async (req) => {
  const { uid: adminUid } = await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { reqId, reportId, outcome, note } = parsed.data;

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
        `Cannot resolve a ${reportData.status} report.`,
      );
    }

    const newRequestStatus = OUTCOME_TO_REQUEST_STATUS[outcome];
    tx.update(reqRef, {
      status: newRequestStatus,
      decidedBy: adminUid,
      decidedAt: Timestamp.now(),
    });
    tx.update(reportRef, {
      status: "resolved",
      resolution: outcome,
      resolutionNote: note,
      resolvedBy: adminUid,
      resolvedAt: Timestamp.now(),
    });

    return reqSnap.data()?.userId as string;
  });

  void sendToUser(ownerUid, {
    title: outcome === "confirm_with_remedy"
      ? "Report resolved — delivery accepted"
      : "Report resolved — delivery failed",
    body: note,
    deepLink: `/user/history`,
    data: { type: "report_resolved", requestId: reqId, reportId, outcome },
  });

  return { ok: true };
});
