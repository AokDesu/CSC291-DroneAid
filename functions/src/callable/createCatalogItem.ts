// Admin-callable: create a new catalog item.
// Spec: §10 createCatalogItem, flow F-24.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  itemId: z.string().regex(/^[a-z0-9][a-z0-9\-]{1,40}$/),
  name: z.string().min(1).max(40),
  weightKg: z.number().positive().max(6),
  initialStock: z.number().int().min(0).max(9999),
  icon: z.string().max(40).optional(),
  active: z.boolean().default(true),
});

export const createCatalogItem = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);
  const p = parsed.data;

  const ref = db.doc(`catalog/${p.itemId}`);
  const exists = await ref.get();
  if (exists.exists) throw new HttpsError("already-exists", "Item id already in use.");

  await ref.set({
    name: p.name,
    weightKg: p.weightKg,
    stock: p.initialStock,
    icon: p.icon ?? null,
    active: p.active,
  });

  return { ok: true, itemId: p.itemId };
});
