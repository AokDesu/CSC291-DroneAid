// Auth trigger: provision users/{uid} on first sign-in.
// Spec: §5 auth/roles, §10 onUserCreated.
//
// The synthetic email format is `<nationalId>@drone-aid.local`. We extract
// the national ID from it. If a record already exists (e.g. seed script
// pre-created it), we merge instead of overwriting.

import * as functions from "firebase-functions/v1";
import { db, FieldValue } from "../lib/admin";

const EMAIL_SUFFIX = "@drone-aid.local";

export const onUserCreated = functions
  .region("asia-southeast1")
  .auth.user()
  .onCreate(async (user) => {
    let nationalId: string | null = null;
    if (user.email && user.email.endsWith(EMAIL_SUFFIX)) {
      nationalId = user.email.slice(0, -EMAIL_SUFFIX.length);
    }

    // Preserve any fields already written by a seed script. Seeds run set()
    // immediately after createUser() and may race this trigger; without the
    // pre-read, the trigger's "role: user" default would clobber an admin
    // role written by seedAdmins.
    const docRef = db.doc(`users/${user.uid}`);
    const existing = (await docRef.get()).data() ?? {};

    await docRef.set({
      nationalId: existing.nationalId ?? nationalId,
      name: existing.name ?? user.displayName ?? null,
      phone: existing.phone ?? user.phoneNumber ?? null,
      role: existing.role ?? "user",
      deliveryAddress: existing.deliveryAddress ?? null,
      hubLocation: existing.hubLocation ?? null,
      locked: existing.locked ?? false,
      fcmTokens: existing.fcmTokens ?? [],
      createdAt: existing.createdAt ?? FieldValue.serverTimestamp(),
    }, { merge: true });
  });
