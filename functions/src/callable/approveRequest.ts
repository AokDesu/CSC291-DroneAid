// Admin-callable: approve a pending request, decrement stock atomically,
// return list of eligible drones for the assignment step.
// Spec: §10 approveRequest, flow F-16.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue, Timestamp } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { haversineKm } from "../lib/geo";

const InputSchema = z.object({ reqId: z.string().min(1) });

const RANGE_KM = 15;
const MIN_BATTERY = 30;

export const approveRequest = onCall(async (req) => {
  const { uid: adminUid } = await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const reqRef = db.doc(`requests/${parsed.data.reqId}`);

  // Transaction: validate stock again under lock, then decrement + flip status.
  const totals = await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqSnap.data() ?? {};
    if (r.status !== "pending") {
      throw new HttpsError("failed-precondition", `Cannot approve a ${r.status} request.`);
    }

    // Load every catalog item we're about to decrement.
    const items = (r.items ?? []) as { catalogId: string; qty: number }[];
    const catalogRefs = items.map((i) => db.doc(`catalog/${i.catalogId}`));
    const catalogSnaps = await Promise.all(catalogRefs.map((ref) => tx.get(ref)));
    for (let i = 0; i < items.length; i++) {
      const snap = catalogSnaps[i];
      if (!snap.exists) throw new HttpsError("not-found", `Item ${items[i].catalogId} missing.`);
      const d = snap.data() ?? {};
      if ((d.stock ?? 0) < items[i].qty) {
        throw new HttpsError("failed-precondition", `Item ${d.name} is now out of stock.`);
      }
    }

    // Decrement stock + flip request status.
    for (let i = 0; i < items.length; i++) {
      tx.update(catalogRefs[i], { stock: FieldValue.increment(-items[i].qty) });
    }
    tx.update(reqRef, {
      status: "approved",
      decidedBy: adminUid,
      decidedAt: Timestamp.now(),
    });
    return r;
  });

  // Fetch idle drones, filter by payload + range + battery.
  const droneSnap = await db.collection("drones").where("status", "==", "idle").get();
  const dest = (totals.deliveryAddress as { lat: number; lng: number });
  const eligible = droneSnap.docs
    .map((d) => ({ id: d.id, ...d.data() } as Record<string, unknown> & { id: string }))
    .filter((d) => {
      const base = d.baseLocation as { lat: number; lng: number } | undefined;
      const maxPayload = (d.maxPayloadKg as number | undefined) ?? 0;
      const battery = (d.batteryPct as number | undefined) ?? 0;
      if (!base) return false;
      if (battery < MIN_BATTERY) return false;
      if (maxPayload < (totals.totalWeightKg as number)) return false;
      if (haversineKm(base, dest) > RANGE_KM) return false;
      return true;
    });

  return { eligibleDrones: eligible };
});
