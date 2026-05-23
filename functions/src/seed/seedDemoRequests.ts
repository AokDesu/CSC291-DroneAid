// Idempotent seed for demo `requests/*` docs used in the screencast.
// Creates one request in each demo-relevant status (pending, in_flight,
// delivered) so admin + history pages aren't empty at first load.
//
// Idempotency: each request uses a deterministic doc id; existing docs are
// preserved so re-runs don't blow away mid-demo edits.

import { db, Timestamp } from "../lib/admin";

const DEMO_TAG = "demo-screencast-2026-06";
const NOW = Date.now();
const MIN = 60 * 1000;

type Status = "pending" | "in_flight" | "delivered";

interface DemoRequest {
  id: string;
  userId: string;
  items: { catalogId: string; qty: number }[];
  totalWeightKg: number;
  deliveryAddress: { lat: number; lng: number; label: string };
  priority: "normal" | "urgent";
  status: Status;
  notes: string | null;
  decidedBy: string | null;
  decidedOffsetMs: number | null;
  createdOffsetMs: number;
  currentFlightId: string | null;
}

const REQUESTS: DemoRequest[] = [
  {
    id: "demo-req-pending",
    userId: "user-mali",
    items: [
      { catalogId: "food-kit", qty: 1 },
      { catalogId: "blanket", qty: 1 },
    ],
    totalWeightKg: 2.5,
    deliveryAddress: { lat: 13.7563, lng: 100.5018, label: "Bangkok central shelter" },
    priority: "normal",
    status: "pending",
    notes: "Awaiting admin review.",
    decidedBy: null,
    decidedOffsetMs: null,
    createdOffsetMs: 0,
    currentFlightId: null,
  },
  {
    id: "demo-req-in-flight",
    userId: "user-naree",
    items: [
      { catalogId: "medical-kit", qty: 1 },
      { catalogId: "baby-formula", qty: 1 },
    ],
    totalWeightKg: 2.2,
    deliveryAddress: { lat: 13.7460, lng: 100.5300, label: "East shelter" },
    priority: "urgent",
    status: "in_flight",
    notes: "Urgent medical drop.",
    decidedBy: "droneaid-admin",
    decidedOffsetMs: 30 * MIN,
    createdOffsetMs: 35 * MIN,
    currentFlightId: "demo-flight-001",
  },
  {
    id: "demo-req-delivered",
    userId: "user-somchai",
    items: [{ catalogId: "water-5l", qty: 1 }],
    totalWeightKg: 5.0,
    deliveryAddress: { lat: 13.7700, lng: 100.5300, label: "North shelter" },
    priority: "normal",
    status: "delivered",
    notes: null,
    decidedBy: "droneaid-admin",
    decidedOffsetMs: 2 * 60 * MIN,
    createdOffsetMs: 2 * 60 * MIN + 5 * MIN,
    currentFlightId: null,
  },
];

export async function seedDemoRequests(): Promise<void> {
  let wrote = 0;
  for (const r of REQUESTS) {
    const ref = db.doc(`requests/${r.id}`);
    const snap = await ref.get();
    if (snap.exists) continue;
    const createdAt = Timestamp.fromMillis(NOW - r.createdOffsetMs);
    const decidedAt =
      r.decidedOffsetMs !== null ? Timestamp.fromMillis(NOW - r.decidedOffsetMs) : null;
    await ref.set({
      userId: r.userId,
      items: r.items,
      totalWeightKg: r.totalWeightKg,
      deliveryAddress: r.deliveryAddress,
      priority: r.priority,
      status: r.status,
      notes: r.notes,
      decidedBy: r.decidedBy,
      decidedAt,
      rejectReason: null,
      currentFlightId: r.currentFlightId,
      createdAt,
      demoTag: DEMO_TAG,
    });
    wrote++;
  }
  console.log(`seedDemoRequests: wrote ${wrote}/${REQUESTS.length} demo requests.`);
}
