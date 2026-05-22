// Idempotent seed for the demo admin (and a placeholder password).
// Per design-spec §4.1. Run once after firebase deploy.
//
// SECURITY: passwords here are obvious demo strings. Never use this script
// against a production project; the redactor catches IDs but not these
// passwords.

import { auth, db } from "../lib/admin";

interface SeedAdmin {
  uid: string;
  nationalId: string;
  name: string;
  email: string;
  password: string;
  phone: string;
}

const ADMINS: SeedAdmin[] = [
  {
    uid: "admin-aok",
    nationalId: "1100000000001",
    name: "Aok Lead",
    email: "1100000000001@drone-aid.local",
    password: "Admin#001",
    phone: "+66810000001",
  },
];

export async function seedAdmins(): Promise<void> {
  for (const a of ADMINS) {
    // Upsert Auth user.
    try {
      await auth.getUser(a.uid);
    } catch {
      await auth.createUser({
        uid: a.uid,
        email: a.email,
        emailVerified: true,
        password: a.password,
        displayName: a.name,
        disabled: false,
      });
    }

    // Upsert users doc with role=admin (overrides what onUserCreated wrote).
    await db.doc(`users/${a.uid}`).set({
      nationalId: a.nationalId,
      name: a.name,
      phone: a.phone,
      role: "admin",
      locked: false,
      fcmTokens: [],
      deliveryAddress: null,
    }, { merge: true });
  }
  console.log(`seedAdmins: ensured ${ADMINS.length} admin(s).`);
}
