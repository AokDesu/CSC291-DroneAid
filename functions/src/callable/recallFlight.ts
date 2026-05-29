// Admin-callable: force a mid-flight drone to head home.
// See docs/adr/0005-recall-and-storm-evacuation.md.
//
// Valid source statuses are `enroute` and `delivering`. `returning`
// flights are already heading home so the call is a no-op (rejected).
// `completed` / `aborted` / `failed` are terminal and rejected.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { recallFlightTx } from "../lib/flights";
import { sendToUser } from "../lib/fcm";
import { snapshot } from "../lib/sim";
import { type WeatherState } from "../lib/weather";

const InputSchema = z.object({
  flightId: z.string().min(1),
});

const RECALLABLE_STATUSES = new Set(["enroute", "delivering"]);

export const recallFlight = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { flightId } = parsed.data;

  const nowMs = Date.now();
  const weatherSnap = await db.doc("weather/current").get();
  const weather = ((weatherSnap.data()?.state as WeatherState) ?? "clear");

  const flightRef = db.doc(`flights/${flightId}`);

  const userId = await db.runTransaction(async (tx) => {
    const snap = await tx.get(flightRef);
    if (!snap.exists) throw new HttpsError("not-found", "Flight not found.");
    const f = snap.data() ?? {};
    if (!RECALLABLE_STATUSES.has(f.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot recall a ${f.status} flight.`,
      );
    }
    const flightState = {
      origin: f.origin as { lat: number; lng: number },
      destination: f.destination as { lat: number; lng: number },
      takeoffAt: (f.takeoffAt as FirebaseFirestore.Timestamp).toMillis(),
      speedKmh: f.speedKmh as number,
      weatherModifierAtTakeoff: f.weatherModifierAtTakeoff as number,
      batteryAtTakeoff: f.batteryAtTakeoff as number,
    };
    const currentSnap = snapshot(flightState, nowMs, weather);
    recallFlightTx(tx, {
      flightId,
      droneId: f.droneId as string,
      requestId: f.requestId as string,
      nowMs,
      batteryAtReturnStart: currentSnap.battery,
    });
    return f.userId as string;
  });

  void sendToUser(userId, {
    title: "Flight recalled",
    body: "Your drone is returning to base. Please submit a new request.",
    deepLink: `/user/history`,
    data: { type: "flight_recalled", flightId },
  });

  return { ok: true };
});
