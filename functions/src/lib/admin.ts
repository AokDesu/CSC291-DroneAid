// Firebase Admin SDK singleton + commonly re-exported types.
// Initialized lazily so test suites can swap apps via initializeApp().

import { initializeApp, getApps, type App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

const app: App = getApps().length === 0 ? initializeApp() : getApps()[0];

export const db = getFirestore(app);
export const auth = getAuth(app);
export { FieldValue, Timestamp };
