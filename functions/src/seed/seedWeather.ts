// Idempotent seed for weather/current.

import { db, FieldValue } from "../lib/admin";

export async function seedWeather(): Promise<void> {
  await db.doc("weather/current").set({
    state: "clear",
    updatedBy: "seed",
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log("seedWeather: weather/current=clear.");
}
