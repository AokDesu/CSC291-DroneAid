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

    await db.doc(`users/${user.uid}`).set({
      nationalId,
      name: user.displayName ?? null,
      phone: user.phoneNumber ?? null,
      role: "user",
      deliveryAddress: null,
      locked: false,
      fcmTokens: [],
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
