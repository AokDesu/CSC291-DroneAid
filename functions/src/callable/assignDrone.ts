// Admin-callable: pick a drone for an approved request, create a flight,
// transition drone + request statuses atomically. FCMs the user.
// Spec: §10 assignDrone, flow F-18.

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, Timestamp } from "../lib/admin";
import { requireAdmin } from "../lib/roles";
import { sendToUser } from "../lib/fcm";
import { computeEta } from "../lib/sim";
import { speedMod, type WeatherState } from "../lib/weather";

const InputSchema = z.object({
  reqId: z.string().min(1),
  droneId: z.string().min(1),
});

const BASE_SPEED_KMH = 15;

export const assignDrone = onCall(async (req) => {
  await requireAdmin(req);
  const parsed = InputSchema.safeParse(req.data);
  if (!parsed.success) throw new HttpsError("invalid-argument", parsed.error.message);
  const { reqId, droneId } = parsed.data;

  // Snapshot weather BEFORE the transaction so all reads in the tx are stable.
  const weatherSnap = await db.doc("weather/current").get();
  const weatherState = ((weatherSnap.data()?.state as WeatherState) ?? "clear");
  const weatherMod = speedMod(weatherState);

  const { flightId, userId } = await db.runTransaction(async (tx) => {
    const reqRef = db.doc(`requests/${reqId}`);
    const droneRef = db.doc(`drones/${droneId}`);
    const [reqSnap, droneSnap] = await Promise.all([tx.get(reqRef), tx.get(droneRef)]);

    if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
    if (!droneSnap.exists) throw new HttpsError("not-found", "Drone not found.");
    const r = reqSnap.data() ?? {};
    const d = droneSnap.data() ?? {};

    // Acceptable starting states: approved (first dispatch) or failed (reassign).
    if (r.status !== "approved" && r.status !== "failed") {
      throw new HttpsError("failed-precondition", `Cannot assign on a ${r.status} request.`);
    }
    if (d.status !== "idle") {
      throw new HttpsError("failed-precondition", `DRN ${droneId} is ${d.status}, not idle.`);
    }
    if ((d.maxPayloadKg ?? 0) < (r.totalWeightKg ?? 0)) {
      throw new HttpsError("failed-precondition", "Drone payload too small.");
    }

    const takeoffAt = Timestamp.now();
    const flightRef = db.collection("flights").doc();
    const origin = d.baseLocation as { lat: number; lng: number };
    const destination = r.deliveryAddress as { lat: number; lng: number };

    const eta = computeEta({
      origin,
      destination,
      takeoffAt: takeoffAt.toMillis(),
      speedKmh: BASE_SPEED_KMH,
      weatherModifierAtTakeoff: weatherMod,
      batteryAtTakeoff: (d.batteryPct as number) ?? 100,
    });

    tx.set(flightRef, {
      droneId,
      requestId: reqId,
      userId: r.userId,
      status: "enroute",
      origin,
      destination,
      takeoffAt,
      etaAt: Timestamp.fromMillis(eta),
      speedKmh: BASE_SPEED_KMH,
      weatherModifierAtTakeoff: weatherMod,
      batteryAtTakeoff: d.batteryPct,
      failureType: null,
    });

    tx.update(droneRef, { status: "flying", currentFlightId: flightRef.id });
    tx.update(reqRef, { status: "in_flight", currentFlightId: flightRef.id });

    return { flightId: flightRef.id, userId: r.userId as string };
  });

  void sendToUser(userId, {
    title: "Drone dispatched",
    body: "Watch your tracking page for live updates.",
    deepLink: `/user/tracking/${flightId}`,
    data: { type: "flight_dispatched", requestId: reqId, flightId },
  });

  return { flightId };
});
