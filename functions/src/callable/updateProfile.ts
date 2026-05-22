// User-callable: update own profile fields.
// Spec: §10 updateProfile, flow F-04.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireUser } from "../lib/roles";

const InputSchema = z.object({
  name: z.string().min(1).max(60).optional(),
  phone: z.string().regex(/^\+?\d{10,15}$/).optional(),
  deliveryAddress: z.object({
    lat: z.number().gte(-90).lte(90),
    lng: z.number().gte(-180).lte(180),
    label: z.string().max(120).optional(),
  }).optional(),
  prefs: z.object({
    theme: z.enum(["system", "light", "dark"]).optional(),
    notificationsEnabled: z.boolean().optional(),
  }).optional(),
});

export const updateProfile = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);
  const payload = parsed.data;

  // Build a sparse patch — never overwrites fields the user didn't send.
  const patch: Record<string, unknown> = {};
  if (payload.name !== undefined) patch.name = payload.name;
  if (payload.phone !== undefined) patch.phone = payload.phone;
  if (payload.deliveryAddress !== undefined) patch.deliveryAddress = payload.deliveryAddress;
  if (payload.prefs !== undefined) patch.prefs = payload.prefs;

  if (Object.keys(patch).length === 0) return { ok: true };
  await db.doc(`users/${uid}`).update(patch);
  return { ok: true };
});
