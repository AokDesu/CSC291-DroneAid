// Idempotent seed for demo users per design-spec §4.2.
// Generates valid Thai-ID checksums on the fly.

import { auth, db } from "../lib/admin";

function buildId(stem12: string): string {
  if (stem12.length !== 12) throw new Error("stem must be 12 digits");
  const digits = stem12.split("").map((c) => Number.parseInt(c, 10));
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += digits[i] * (13 - i);
  const check = (11 - (sum % 11)) % 10;
  return stem12 + check.toString();
}

interface DemoUser {
  uid: string;
  stem12: string;
  name: string;
  phone: string;
  password: string;
  lat: number;
  lng: number;
  label: string;
}

const USERS: DemoUser[] = [
  { uid: "user-mali",    stem12: "110000000010", name: "Mali Suwan",      phone: "+66810000101", password: "Demo#101", lat: 13.7563, lng: 100.5018, label: "Bangkok central shelter" },
  { uid: "user-naree",   stem12: "110000000010", name: "Naree Charoen",   phone: "+66810000102", password: "Demo#102", lat: 13.7460, lng: 100.5300, label: "East shelter" },
  { uid: "user-somchai", stem12: "110000000010", name: "Somchai T.",      phone: "+66810000103", password: "Demo#103", lat: 13.7700, lng: 100.5300, label: "North shelter" },
];

// All three stems collide intentionally so the script demonstrates how to
// pick distinct stems. Real Day-1 work: rotate stems per user.
const STEM_OFFSETS = ["110000000010", "110000000020", "110000000030"];

export async function seedDemoUsers(): Promise<void> {
  for (let i = 0; i < USERS.length; i++) {
    const u = USERS[i];
    const nationalId = buildId(STEM_OFFSETS[i]);
    const email = `${nationalId}@drone-aid.local`;

    try {
      await auth.getUser(u.uid);
    } catch {
      await auth.createUser({
        uid: u.uid,
        email,
        password: u.password,
        emailVerified: true,
        displayName: u.name,
        disabled: false,
      });
    }

    await db.doc(`users/${u.uid}`).set({
      nationalId,
      name: u.name,
      phone: u.phone,
      role: "user",
      locked: false,
      fcmTokens: [],
      deliveryAddress: { lat: u.lat, lng: u.lng, label: u.label },
    }, { merge: true });
  }
  console.log(`seedDemoUsers: ensured ${USERS.length} demo users.`);
}
