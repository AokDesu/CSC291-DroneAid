// Admin-callable: increment stock for a catalog item.
// Spec: §10 restockItem, flow F-23.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  itemId: z.string().min(1),
  qty: z.number().int().min(1).max(999),
});

export const restockItem = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const ref = db.doc(`catalog/${parsed.data.itemId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Item not found.");
    tx.update(ref, { stock: FieldValue.increment(parsed.data.qty) });
  });

  return { ok: true };
});
