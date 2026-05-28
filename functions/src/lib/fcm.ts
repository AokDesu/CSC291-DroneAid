// FCM fan-out helpers.
// Sends to every token on the user/admin profile(s), then prunes tokens that
// FCM reports as unregistered/invalid (spec §11).

import {
  getMessaging,
  type MulticastMessage,
  type SendResponse,
} from "firebase-admin/messaging";
import { db, FieldValue } from "./admin";

export type NotificationPayload = {
  title: string;
  body: string;
  deepLink: string;
  data?: Record<string, string>;
};

type TokenRef = { uid: string; token: string };

const STALE_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

async function fanOut(refs: TokenRef[], payload: NotificationPayload): Promise<void> {
  if (refs.length === 0) {
    console.log("[fcm] no tokens to send to:", payload.title);
    return;
  }
  const tokens = refs.map((r) => r.token);
  const msg: MulticastMessage = {
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { ...(payload.data ?? {}), deepLink: payload.deepLink },
  };
  try {
    const res = await getMessaging().sendEachForMulticast(msg);
    console.log(`[fcm] sent ${res.successCount}/${tokens.length}: ${payload.title}`);
    await pruneStaleTokens(refs, res.responses);
  } catch (e) {
    console.error("[fcm] send error", e);
  }
}

async function pruneStaleTokens(
  refs: TokenRef[],
  responses: SendResponse[],
): Promise<void> {
  const stalePerUid = new Map<string, string[]>();
  responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error?.code;
    if (!code || !STALE_CODES.has(code)) return;
    const { uid, token } = refs[i];
    const list = stalePerUid.get(uid) ?? [];
    list.push(token);
    stalePerUid.set(uid, list);
  });
  if (stalePerUid.size === 0) return;
  await Promise.all(
    Array.from(stalePerUid.entries()).map(([uid, stale]) =>
      db.doc(`users/${uid}`).update({
        fcmTokens: FieldValue.arrayRemove(...stale),
      }),
    ),
  );
  const total = Array.from(stalePerUid.values()).reduce((n, l) => n + l.length, 0);
  console.log(
    `[fcm] pruned ${total} stale token(s) across ${stalePerUid.size} user(s)`,
  );
}

function writeInbox(uid: string, payload: NotificationPayload): Promise<void> {
  return db.collection(`users/${uid}/notifications`).add({
    title: payload.title,
    body: payload.body,
    deepLink: payload.deepLink,
    createdAt: FieldValue.serverTimestamp(),
    readAt: null,
  }).then(() => undefined);
}

export async function sendToUser(uid: string, payload: NotificationPayload): Promise<void> {
  const snap = await db.doc(`users/${uid}`).get();
  const tokens = (snap.data()?.fcmTokens as string[] | undefined) ?? [];
  await Promise.all([
    fanOut(tokens.map((token) => ({ uid, token })), payload),
    writeInbox(uid, payload),
  ]);
}

export async function sendToAdmins(payload: NotificationPayload): Promise<void> {
  const snap = await db.collection("users").where("role", "==", "admin").get();
  const refs: TokenRef[] = [];
  for (const doc of snap.docs) {
    const t = (doc.data().fcmTokens as string[] | undefined) ?? [];
    for (const token of t) refs.push({ uid: doc.id, token });
  }
  await Promise.all([
    fanOut(refs, payload),
    ...snap.docs.map((doc) => writeInbox(doc.id, payload)),
  ]);
}
