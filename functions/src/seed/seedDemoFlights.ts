// Idempotent seed for one in-flight `flights/*` doc paired with
// `requests/demo-req-in-flight`. Also flips drn-001 to `flying` so the
// tracking + admin pages show a live mission at first load.

import { db, Timestamp } from "../lib/admin";

const DEMO_TAG = "demo-screencast-2026-06";
const FLIGHT_ID = "demo-flight-001";
const DRONE_ID = "drn-001";

const NOW = Date.now();
const MIN = 60 * 1000;

export async function seedDemoFlights(): Promise<void> {
  const flightRef = db.doc(`flights/${FLIGHT_ID}`);
  const snap = await flightRef.get();
  if (snap.exists) {
    console.log(`seedDemoFlights: ${FLIGHT_ID} already present, skipping.`);
    return;
  }
  const takeoffAt = Timestamp.fromMillis(NOW - 25 * MIN);
  const etaAt = Timestamp.fromMillis(NOW + 5 * MIN);
  await flightRef.set({
    droneId: DRONE_ID,
    requestId: "demo-req-in-flight",
    userId: "user-naree",
    status: "enroute",
    origin: { lat: 13.74, lng: 100.54 },
    destination: { lat: 13.7460, lng: 100.5300 },
    takeoffAt,
    etaAt,
    speedKmh: 15,
    weatherModifierAtTakeoff: 1.0,
    batteryAtTakeoff: 100,
    failureType: null,
    demoTag: DEMO_TAG,
  });
  await db.doc(`drones/${DRONE_ID}`).update({
    status: "flying",
    currentFlightId: FLIGHT_ID,
  });
  console.log(`seedDemoFlights: wrote 1 demo flight (${FLIGHT_ID}).`);
}
