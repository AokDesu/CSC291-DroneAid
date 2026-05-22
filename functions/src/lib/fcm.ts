// FCM fan-out helpers.
// Stub: logs payload + sends to every token on the user/admin profile(s).
// TODO(Aok): wire delivery-receipt cleanup of stale tokens (spec §11).

import { getMessaging, type MulticastMessage } from "firebase-admin/messaging";
import { db } from "./admin";

export type NotificationPayload = {
  title: string;
  body: string;
  deepLink: string;
  data?: Record<string, string>;
};

async function fanOut(tokens: string[], payload: NotificationPayload): Promise<void> {
  if (tokens.length === 0) {
    console.log("[fcm] no tokens to send to:", payload.title);
    return;
  }
  const msg: MulticastMessage = {
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { ...(payload.data ?? {}), deepLink: payload.deepLink },
  };
  try {
    const res = await getMessaging().sendEachForMulticast(msg);
    console.log(`[fcm] sent ${res.successCount}/${tokens.length}: ${payload.title}`);
  } catch (e) {
    console.error("[fcm] send error", e);
  }
}

export async function sendToUser(uid: string, payload: NotificationPayload): Promise<void> {
  const snap = await db.doc(`users/${uid}`).get();
  const tokens = (snap.data()?.fcmTokens as string[] | undefined) ?? [];
  await fanOut(tokens, payload);
}

export async function sendToAdmins(payload: NotificationPayload): Promise<void> {
  const snap = await db.collection("users").where("role", "==", "admin").get();
  const tokens: string[] = [];
  for (const doc of snap.docs) {
    const t = (doc.data().fcmTokens as string[] | undefined) ?? [];
    tokens.push(...t);
  }
  await fanOut(tokens, payload);
}
