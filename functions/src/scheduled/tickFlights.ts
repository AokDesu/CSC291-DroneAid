// Scheduled tick: every 60 s, advance every active flight.
// Spec: §8 sim engine, §10 tickFlights, flow F-19/F-20.

import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, Timestamp } from "../lib/admin";
import { type WeatherState } from "../lib/weather";
import { deliveringHoldElapsed, rollAbort, snapshot } from "../lib/sim";

const ACTIVE_STATUSES = ["enroute", "delivering", "returning"] as const;

/// Advances every active flight one tick. Pure body — reusable from the
/// scheduled wrapper below and from `devTickFlights` (dev-only callable for
/// the emulator, where scheduled triggers do not fire).
///
/// Returns `{ count }` so callers can surface "ticked N flights" to the UI.
export async function tickAllFlights(nowMs: number = Date.now()): Promise<{ count: number }> {
  const weatherSnap = await db.doc("weather/current").get();
  const weather = ((weatherSnap.data()?.state as WeatherState) ?? "clear");

  const flightsSnap = await db
    .collection("flights")
    .where("status", "in", ACTIVE_STATUSES as unknown as string[])
    .get();

  for (const doc of flightsSnap.docs) {
    const f = doc.data();
    const flightState = {
      origin: f.origin,
      destination: f.destination,
      takeoffAt: (f.takeoffAt as FirebaseFirestore.Timestamp).toMillis(),
      speedKmh: f.speedKmh as number,
      weatherModifierAtTakeoff: f.weatherModifierAtTakeoff as number,
      batteryAtTakeoff: f.batteryAtTakeoff as number,
    };
    const snap = snapshot(flightState, nowMs, weather);

    const status = f.status as (typeof ACTIVE_STATUSES)[number];
    const requestId = f.requestId as string;
    const droneId = f.droneId as string;

    // ── Enroute: roll failure dice, otherwise advance toward delivering ────
    if (status === "enroute") {
      const abort = rollAbort({ weather, battery: snap.battery });
      if (abort) {
        await failFlight(doc.id, requestId, droneId, abort, snap.battery);
        continue;
      }
      if (snap.progress >= 1.0) {
        await doc.ref.update({
          status: "delivering",
          deliveringStartedAt: Timestamp.fromMillis(nowMs),
        });
        continue;
      }
      continue; // still in flight, no DB write needed
    }

    // ── Delivering: hold 60 s then complete ──────────────────────────────
    if (status === "delivering") {
      const startMs = (f.deliveringStartedAt as FirebaseFirestore.Timestamp | undefined)
        ?.toMillis() ?? nowMs;
      if (deliveringHoldElapsed(startMs, nowMs)) {
        await db.runTransaction(async (tx) => {
          tx.update(doc.ref, { status: "completed" });
          tx.update(db.doc(`requests/${requestId}`), { status: "delivered" });
        });
      }
      continue;
    }

    // ── Returning: when drone gets back, set drone idle ──────────────────
    if (status === "returning") {
      const returningStartedAt =
        (f.returningStartedAt as FirebaseFirestore.Timestamp | undefined)?.toMillis() ?? nowMs;
      // Reuse snapshot math by swapping origin/destination since we're heading home.
      const back = snapshot(
        { ...flightState, takeoffAt: returningStartedAt, origin: f.destination, destination: f.origin },
        nowMs,
        weather,
      );
      if (back.progress >= 1.0) {
        await db.runTransaction(async (tx) => {
          tx.update(doc.ref, { status: "completed", archived: true });
          tx.update(db.doc(`drones/${droneId}`), {
            status: "idle",
            currentFlightId: null,
            batteryPct: Math.max(0, Math.floor(snap.battery)),
          });
        });
      }
      continue;
    }
  }

  return { count: flightsSnap.size };
}

export const tickFlights = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 120,
    region: "asia-southeast1",
  },
  async () => {
    await tickAllFlights(Date.now());
  },
);

async function failFlight(
  flightId: string,
  requestId: string,
  droneId: string,
  failureType: "weather" | "battery" | "mechanical",
  batteryRemaining: number,
): Promise<void> {
  const requestStatus = "failed";
  const flightStatus = failureType === "mechanical" ? "failed" : "aborted";
  const droneNext = failureType === "mechanical" || batteryRemaining <= 0 ? "maintenance" : "idle";

  await db.runTransaction(async (tx) => {
    tx.update(db.doc(`flights/${flightId}`), {
      status: flightStatus,
      failureType,
    });
    tx.update(db.doc(`requests/${requestId}`), {
      status: requestStatus,
    });
    tx.update(db.doc(`drones/${droneId}`), {
      status: droneNext,
      currentFlightId: null,
      batteryPct: Math.max(0, Math.floor(batteryRemaining)),
    });
  });
}
