// Admin-callable: edit an existing catalog item's name / weightKg / icon.
// Sibling of restockItem (stock-only) and toggleCatalogActive (active-only).
// itemId is the Firestore doc id and is intentionally immutable — every
// historical Request.items[].catalogId references it.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  itemId: z.string().min(1),
  name: z.string().min(1).max(40).optional(),
  weightKg: z.number().positive().max(6).optional(),
  icon: z.string().max(40).nullable().optional(),
});

export const editCatalogItem = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { itemId, ...changes } = parsed.data;

  if (Object.keys(changes).length === 0) {
    throw new HttpsError("invalid-argument", "Nothing to update.");
  }

  const ref = db.doc(`catalog/${itemId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Item not found.");
    tx.update(ref, changes);
  });

  return { ok: true };
});
