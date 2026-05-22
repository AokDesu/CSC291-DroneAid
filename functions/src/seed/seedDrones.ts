// Idempotent seed for drones/* per design-spec §4.4.

import { db } from "../lib/admin";

const BASE = { lat: 13.74, lng: 100.54 };
const FLEET = ["drn-001", "drn-002", "drn-003", "drn-004", "drn-005", "drn-006", "drn-007", "drn-008"];

export async function seedDrones(): Promise<void> {
  const batch = db.batch();
  for (const id of FLEET) {
    batch.set(db.doc(`drones/${id}`), {
      name: id.toUpperCase().replace("-", "-"),
      status: "idle",
      batteryPct: 100,
      baseLocation: BASE,
      maxPayloadKg: 6.0,
      currentFlightId: null,
      lastSeenAt: new Date(),
    }, { merge: true });
  }
  await batch.commit();
  console.log(`seedDrones: wrote ${FLEET.length} drones.`);
}
