// User-callable: confirm receipt of a delivered request.
// Spec: §10 confirmDelivery, flow F-13.
//
// Two entry paths:
//   1. status=delivered (server tickFlights flipped it after the 60s
//      delivering hold) — straight transition to confirmed.
//   2. status=in_flight (user pressed the Tracking page arrival CTA
//      while still mid-flight) — server re-runs the simulator snapshot
//      from takeoffAt/speedKmh/weather and requires progress ≥ 0.95
//      before collapsing the delivered+confirmed states into one tx.
//      Anti-cheat: a malicious client can't confirm an enroute flight
//      that the server doesn't think has arrived.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireUser } from "../lib/roles";
import { sendToUser } from "../lib/fcm";
import { snapshot } from "../lib/sim";
import { type WeatherState } from "../lib/weather";

const InputSchema = z.object({ reqId: z.string().min(1) });

const ARRIVAL_PROGRESS_THRESHOLD = 0.95;

export const confirmDelivery = onCall(async (req) => {
  const { uid } = await requireUser(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);

  // Weather read happens before the transaction so we don't waste a
  // tx attempt on it; matches the pattern in scheduled/tickFlights.ts.
  const weatherSnap = await db.doc("weather/current").get();
  const weather = ((weatherSnap.data()?.state as WeatherState) ?? "clear");
  const nowMs = Date.now();

  const reqRef = db.doc(`requests/${parsed.data.reqId}`);
  await db.runTransaction(async (tx) => {
    // ── All reads first (Firestore tx requirement) ─────────────────────
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqSnap.data() ?? {};
    if (r.userId !== uid) throw new HttpsError("permission-denied", "Not your request.");
    if (r.status === "confirmed") return; // idempotent

    const flightRef = r.currentFlightId
      ? db.doc(`flights/${r.currentFlightId}`)
      : null;
    const flightSnap = flightRef ? await tx.get(flightRef) : null;

    // ── Then writes ────────────────────────────────────────────────────
    if (r.status === "delivered") {
      tx.update(reqRef, { status: "confirmed", decidedAt: Timestamp.now() });
      if (flightRef && flightSnap?.exists) {
        // Drone has been at the destination through the delivering hold —
        // its battery is the outbound-trip battery at progress=1.0.
        const f = flightSnap.data() ?? {};
        const arrivalSnap = snapshot(
          {
            origin: f.origin,
            destination: f.destination,
            takeoffAt: (f.takeoffAt as FirebaseFirestore.Timestamp).toMillis(),
            speedKmh: f.speedKmh as number,
            weatherModifierAtTakeoff: f.weatherModifierAtTakeoff as number,
            batteryAtTakeoff: f.batteryAtTakeoff as number,
          },
          nowMs,
          weather,
        );
        tx.update(flightRef, {
          status: "returning",
          returningStartedAt: Timestamp.now(),
          batteryAtReturnStart: arrivalSnap.battery,
        });
      }
      return;
    }

    if (r.status === "in_flight") {
      if (!flightRef || !flightSnap?.exists) {
        throw new HttpsError("failed-precondition", "Linked flight not found.");
      }
      const f = flightSnap.data() ?? {};
      const snap = snapshot(
        {
          origin: f.origin,
          destination: f.destination,
          takeoffAt: (f.takeoffAt as FirebaseFirestore.Timestamp).toMillis(),
          speedKmh: f.speedKmh as number,
          weatherModifierAtTakeoff: f.weatherModifierAtTakeoff as number,
          batteryAtTakeoff: f.batteryAtTakeoff as number,
        },
        nowMs,
        weather,
      );
      if (snap.progress < ARRIVAL_PROGRESS_THRESHOLD) {
        throw new HttpsError(
          "failed-precondition",
          "Drone has not arrived yet.",
        );
      }
      // Collapse delivered+confirmed into one transition. Skip the 60s
      // delivering hold — the user has explicitly acknowledged receipt.
      tx.update(reqRef, { status: "confirmed", decidedAt: Timestamp.now() });
      tx.update(flightRef, {
        status: "returning",
        returningStartedAt: Timestamp.now(),
        batteryAtReturnStart: snap.battery,
      });
      return;
    }

    throw new HttpsError("failed-precondition", `Cannot confirm a ${r.status} request.`);
  });

  void sendToUser(uid, {
    title: "Delivery confirmed",
    body: "Thanks — your drone is heading home.",
    deepLink: `/user/history`,
    data: { type: "delivery_confirmed", requestId: parsed.data.reqId },
  });

  return { ok: true };
});
