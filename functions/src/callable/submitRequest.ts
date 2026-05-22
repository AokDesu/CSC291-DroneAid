// User-callable: create a new request in status "pending".
// Validates payload + total weight ≤ max drone payload + stock availability.
// FCMs all admins on success.
//
// Spec: §10 submitRequest, design-spec §7 flow F-07.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";
import { sendToAdmins } from "../lib/fcm";

const MAX_PAYLOAD_KG = 6.0;

const InputSchema = z.object({
  items: z.array(
    z.object({
      catalogId: z.string().min(1),
      qty: z.number().int().min(1).max(10),
    }),
  ).min(1).max(10),
  deliveryAddress: z.object({
    lat: z.number().gte(-90).lte(90),
    lng: z.number().gte(-180).lte(180),
    label: z.string().max(120).optional(),
  }),
  priority: z.enum(["normal", "urgent"]).default("normal"),
  notes: z.string().max(500).optional(),
});

export const submitRequest = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const input = parsed.data;

  // Compute total weight by reading catalog docs in one batch.
  const catalogRefs = input.items.map((i) => db.doc(`catalog/${i.catalogId}`));
  const catalogSnaps = await db.getAll(...catalogRefs);
  let totalWeightKg = 0;
  for (let i = 0; i < input.items.length; i++) {
    const snap = catalogSnaps[i];
    if (!snap.exists) {
      throw new HttpsError("not-found", `Item ${input.items[i].catalogId} not in catalog.`);
    }
    const data = snap.data() ?? {};
    if (data.active !== true) {
      throw new HttpsError("failed-precondition", `Item ${data.name} is inactive.`);
    }
    if ((data.stock ?? 0) < input.items[i].qty) {
      throw new HttpsError("failed-precondition", `Item ${data.name} is out of stock.`);
    }
    totalWeightKg += (data.weightKg as number) * input.items[i].qty;
  }
  if (totalWeightKg > MAX_PAYLOAD_KG) {
    throw new HttpsError(
      "failed-precondition",
      `Total weight ${totalWeightKg.toFixed(1)} kg exceeds drone payload ${MAX_PAYLOAD_KG} kg.`,
    );
  }

  // Create the request. Status defaults to pending.
  const reqRef = db.collection("requests").doc();
  await reqRef.set({
    userId: uid,
    items: input.items,
    totalWeightKg,
    deliveryAddress: input.deliveryAddress,
    priority: input.priority,
    status: "pending",
    notes: input.notes ?? null,
    decidedBy: null,
    decidedAt: null,
    rejectReason: null,
    currentFlightId: null,
    createdAt: Timestamp.now(),
  });

  // FCM admins (fire-and-forget so latency doesn't bite the client).
  void sendToAdmins({
    title: "New request",
    body: `Items: ${input.items.map((i) => i.catalogId).join(", ")} (${totalWeightKg.toFixed(1)} kg)`,
    deepLink: `/admin/requests/${reqRef.id}`,
    data: { type: "request_submitted", requestId: reqRef.id },
  }).catch((e) => console.error("sendToAdmins failed", e));

  // Touch user lastActivityAt for analytics-lite.
  void db.doc(`users/${uid}`).update({ lastActivityAt: FieldValue.serverTimestamp() })
    .catch(() => undefined);

  return { requestId: reqRef.id };
});
