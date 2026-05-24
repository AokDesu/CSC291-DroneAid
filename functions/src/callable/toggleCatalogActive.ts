// Admin-callable: toggle the `active` flag on a catalog item.
// Inactive items are hidden from the user catalog (P-U-03) but kept in
// Firestore for history references. Spec: §6 P-A-07 Deactivate scenario,
// firestore.rules §catalog mention.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  itemId: z.string().min(1),
  active: z.boolean(),
});

export const toggleCatalogActive = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  const ref = db.doc(`catalog/${parsed.data.itemId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Item not found.");
    tx.update(ref, { active: parsed.data.active });
  });

  return { ok: true };
});
