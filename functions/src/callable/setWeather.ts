// Admin-callable: write the global weather state.
// Spec: §10 setWeather, flow F-22.
//
// When the new state is `storm`, every flight currently `enroute` is
// recalled immediately (flight → returning, request → failed). See
// docs/adr/0005-recall-and-storm-evacuation.md for why `delivering`
// and `returning` flights are left alone.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, FieldValue } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { recallFlightTx } from "../lib/flights";
import { sendToUser } from "../lib/fcm";
import { snapshot } from "../lib/sim";

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

  if (parsed.data.state === "storm") {
    await stormEvacuate();
  }

  return { ok: true };
});

async function stormEvacuate(): Promise<void> {
  const nowMs = Date.now();
  const snap = await db
    .collection("flights")
    .where("status", "==", "enroute")
    .get();

  const notifyTargets: Array<{ uid: string; flightId: string }> = [];

  for (const doc of snap.docs) {
    const f = doc.data();
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      if (!fresh.exists) return;
      const r = fresh.data() ?? {};
      // Re-check inside the transaction — another tick may have already
      // moved the flight past enroute (e.g. delivering, or failed).
      if (r.status !== "enroute") return;
      const flightState = {
        origin: r.origin as { lat: number; lng: number },
        destination: r.destination as { lat: number; lng: number },
        takeoffAt: (r.takeoffAt as FirebaseFirestore.Timestamp).toMillis(),
        speedKmh: r.speedKmh as number,
        weatherModifierAtTakeoff: r.weatherModifierAtTakeoff as number,
        batteryAtTakeoff: r.batteryAtTakeoff as number,
      };
      // Weather just flipped to "storm" — use that for the snapshot.
      const currentSnap = snapshot(flightState, nowMs, "storm");
      recallFlightTx(tx, {
        flightId: doc.id,
        droneId: r.droneId as string,
        requestId: r.requestId as string,
        nowMs,
        batteryAtReturnStart: currentSnap.battery,
      });
    });
    if (f.userId) {
      notifyTargets.push({ uid: f.userId as string, flightId: doc.id });
    }
  }

  for (const t of notifyTargets) {
    void sendToUser(t.uid, {
      title: "Flight recalled — storm",
      body: "Weather turned dangerous. Your drone is heading back to base.",
      deepLink: `/user/history`,
      data: { type: "flight_recalled", flightId: t.flightId, cause: "storm" },
    });
  }
}
