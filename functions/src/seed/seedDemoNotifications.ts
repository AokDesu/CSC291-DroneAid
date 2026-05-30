"use strict";
// Idempotent seed: 3 demo notifications for user-naree so the inbox
// shows content on first load without needing a real flight transition.

import { db } from "../lib/admin";

const USER_ID = "user-naree";
const DEMO_TAG = "demo-screencast-2026-06";

export async function seedDemoNotifications(): Promise<void> {
  const col = db.collection(`users/${USER_ID}/notifications`);
  const existing = await col.where("demoTag", "==", DEMO_TAG).limit(1).get();
  if (!existing.empty) {
    console.log("seedDemoNotifications: already seeded, skipping.");
    return;
  }

  const now = Date.now();
  const MIN = 60 * 1000;

  await Promise.all([
    col.add({
      title: "Drone dispatched",
      body: "Your drone is on the way. Track it live.",
      deepLink: "/user/tracking/demo-flight-001",
      createdAt: new Date(now - 30 * MIN),
      readAt: new Date(now - 28 * MIN),
      demoTag: DEMO_TAG,
    }),
    col.add({
      title: "Drone arriving",
      body: "Step outside to receive your supplies.",
      deepLink: "/user/tracking/demo-flight-001",
      createdAt: new Date(now - 5 * MIN),
      readAt: null,
      demoTag: DEMO_TAG,
    }),
    col.add({
      title: "Delivered — please confirm",
      body: "Tap to confirm you received your supplies.",
      deepLink: "/user/confirm/demo-req-delivered",
      createdAt: new Date(now - 1 * MIN),
      readAt: null,
      demoTag: DEMO_TAG,
    }),
  ]);

  console.log("seedDemoNotifications: wrote 3 demo notifications.");
}
