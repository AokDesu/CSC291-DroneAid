// Auth/role gate helpers for v2 onCall handlers.
// Spec: §5 auth/roles. `role` field on users/{uid} is the source of truth.

import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { db } from "./admin";

export async function requireUser(req: CallableRequest): Promise<{ uid: string; role: string }> {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) throw new HttpsError("permission-denied", "Profile not provisioned.");
  const data = snap.data() ?? {};
  if (data.locked === true) throw new HttpsError("permission-denied", "Account locked.");
  const role = (data.role as string | undefined) ?? "user";
  return { uid, role };
}

export async function requireAdmin(req: CallableRequest): Promise<{ uid: string; role: string }> {
  const ctx = await requireUser(req);
  if (ctx.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin role required.");
  }
  return ctx;
}
