// Admin-callable: write the global weather state.
// Spec: §10 setWeather, flow F-22.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue } from "../lib/admin";
import { requireAdmin } from "../lib/roles";

const InputSchema = z.object({
  state: z.enum(["clear", "wind", "storm"]),
});

export const setWeather = onCall(async (req) => {
  const { uid } = await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  await db.doc("weather/current").set({
    state: parsed.data.state,
    updatedBy: uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});
