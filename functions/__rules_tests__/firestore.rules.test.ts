// Firestore security-rules tests.
//
// Run with the firestore emulator already up (`firebase emulators:exec --only
// firestore "npm test -- --testPathPattern __rules_tests__"`). Each test gets
// a clean Firestore via clearFirestore() and re-seeds the baseline docs with
// rules disabled so we only exercise rules in the bodies of the `it()` blocks.

import * as fs from "fs";
import * as path from "path";

import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
} from "firebase/firestore";

const PROJECT_ID = "demo-droneaid-rules";
const RULES_PATH = path.resolve(__dirname, "../..", "firestore.rules");
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST?.split(":")[0] ?? "127.0.0.1";
const EMULATOR_PORT = Number(process.env.FIRESTORE_EMULATOR_HOST?.split(":")[1] ?? 8080);

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, "utf8"),
      host: EMULATOR_HOST,
      port: EMULATOR_PORT,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/user-mali"), {
      role: "user",
      locked: false,
      nationalId: "1100000000101",
      name: "Mali",
      phone: "+66810000101",
      createdAt: 0,
    });
    await setDoc(doc(db, "users/user-naree"), {
      role: "user",
      locked: false,
      nationalId: "1100000000102",
      name: "Naree",
      phone: "+66810000102",
      createdAt: 0,
    });
    await setDoc(doc(db, "users/admin-aok"), {
      role: "admin",
      locked: false,
      nationalId: "1100000000001",
      name: "Aok",
      phone: "+66810000001",
      createdAt: 0,
    });
    await setDoc(doc(db, "catalog/water"), {
      name: "Water 5L",
      weightKg: 5,
      stock: 20,
      active: true,
    });
    await setDoc(doc(db, "requests/req-mali"), {
      userId: "user-mali",
      status: "pending",
      items: [],
      totalWeightKg: 0,
      createdAt: 0,
    });
    await setDoc(doc(db, "requests/req-naree"), {
      userId: "user-naree",
      status: "pending",
      items: [],
      totalWeightKg: 0,
      createdAt: 0,
    });
    await setDoc(doc(db, "drones/drn-001"), {
      status: "idle",
      batteryPct: 100,
      maxPayloadKg: 6,
    });
    await setDoc(doc(db, "flights/flt-mali"), {
      userId: "user-mali",
      requestId: "req-mali",
      droneId: "drn-001",
      status: "enroute",
    });
    await setDoc(doc(db, "weather/current"), {
      state: "clear",
      updatedAt: 0,
      updatedBy: "admin-aok",
    });
    await setDoc(doc(db, "users/user-mali/notifications/notif-1"), {
      title: "Welcome",
      body: "Hello Mali",
      deepLink: "/user/home",
      readAt: null,
      createdAt: 0,
    });
  });
});

const mali = () => env.authenticatedContext("user-mali").firestore();
const naree = () => env.authenticatedContext("user-naree").firestore();
const admin = () => env.authenticatedContext("admin-aok").firestore();
const anon = () => env.unauthenticatedContext().firestore();

// ─── users ────────────────────────────────────────────────────────────────
describe("users/{uid}", () => {
  it("self read", () => assertSucceeds(getDoc(doc(mali(), "users/user-mali"))));
  it("admin reads other", () => assertSucceeds(getDoc(doc(admin(), "users/user-mali"))));
  it("other user denied", () => assertFails(getDoc(doc(naree(), "users/user-mali"))));
  it("anon denied", () => assertFails(getDoc(doc(anon(), "users/user-mali"))));

  it("self updates own name", () =>
    assertSucceeds(updateDoc(doc(mali(), "users/user-mali"), { name: "Mali New" })));

  it("self cannot promote to admin", () =>
    assertFails(updateDoc(doc(mali(), "users/user-mali"), { role: "admin" })));

  it("self cannot change locked", () =>
    assertFails(updateDoc(doc(mali(), "users/user-mali"), { locked: true })));

  it("self cannot change nationalId", () =>
    assertFails(updateDoc(doc(mali(), "users/user-mali"), { nationalId: "9999999999999" })));

  it("admin promotes user to admin", () =>
    assertSucceeds(updateDoc(doc(admin(), "users/user-mali"), { role: "admin" })));

  it("client create always denied", () =>
    assertFails(setDoc(doc(mali(), "users/new-uid"), { role: "user", createdAt: 0 })));

  it("delete denied even for admin", () =>
    assertFails(deleteDoc(doc(admin(), "users/user-naree"))));
});

// ─── notifications subcollection ──────────────────────────────────────────
describe("users/{uid}/notifications/{nid}", () => {
  it("self reads own", () =>
    assertSucceeds(getDoc(doc(mali(), "users/user-mali/notifications/notif-1"))));

  it("other user denied", () =>
    assertFails(getDoc(doc(naree(), "users/user-mali/notifications/notif-1"))));

  it("self may patch readAt", () =>
    assertSucceeds(updateDoc(doc(mali(), "users/user-mali/notifications/notif-1"), {
      readAt: 12345,
    })));

  it("self cannot patch other fields", () =>
    assertFails(updateDoc(doc(mali(), "users/user-mali/notifications/notif-1"), {
      title: "tampered",
    })));

  it("self cannot create", () =>
    assertFails(setDoc(doc(mali(), "users/user-mali/notifications/forged"), {
      title: "x",
      readAt: null,
    })));

  it("self cannot delete", () =>
    assertFails(deleteDoc(doc(mali(), "users/user-mali/notifications/notif-1"))));
});

// ─── catalog ──────────────────────────────────────────────────────────────
describe("catalog/{itemId}", () => {
  it("signed-in user reads", () =>
    assertSucceeds(getDoc(doc(mali(), "catalog/water"))));

  it("anon denied", () =>
    assertFails(getDoc(doc(anon(), "catalog/water"))));

  it("client write denied (user)", () =>
    assertFails(setDoc(doc(mali(), "catalog/food"), {
      name: "Food",
      active: true,
      weightKg: 2,
      stock: 10,
    })));

  it("client write denied (admin)", () =>
    assertFails(setDoc(doc(admin(), "catalog/food"), {
      name: "Food",
      active: true,
      weightKg: 2,
      stock: 10,
    })));
});

// ─── requests ─────────────────────────────────────────────────────────────
describe("requests/{reqId}", () => {
  it("owner reads own", () =>
    assertSucceeds(getDoc(doc(mali(), "requests/req-mali"))));

  it("other user denied", () =>
    assertFails(getDoc(doc(naree(), "requests/req-mali"))));

  it("admin reads any", () =>
    assertSucceeds(getDoc(doc(admin(), "requests/req-naree"))));

  it("client create denied", () =>
    assertFails(setDoc(doc(mali(), "requests/forged"), {
      userId: "user-mali",
      status: "pending",
      items: [],
      createdAt: 0,
    })));

  it("client update denied (even for admin)", () =>
    assertFails(updateDoc(doc(admin(), "requests/req-mali"), { status: "approved" })));
});

// ─── drones ───────────────────────────────────────────────────────────────
describe("drones/{droneId}", () => {
  it("signed-in user reads", () =>
    assertSucceeds(getDoc(doc(mali(), "drones/drn-001"))));

  it("anon denied", () =>
    assertFails(getDoc(doc(anon(), "drones/drn-001"))));

  it("client write denied (admin)", () =>
    assertFails(updateDoc(doc(admin(), "drones/drn-001"), { status: "maintenance" })));
});

// ─── flights ──────────────────────────────────────────────────────────────
describe("flights/{flightId}", () => {
  it("owner reads own (via flight.userId)", () =>
    assertSucceeds(getDoc(doc(mali(), "flights/flt-mali"))));

  it("other user denied", () =>
    assertFails(getDoc(doc(naree(), "flights/flt-mali"))));

  it("admin reads any", () =>
    assertSucceeds(getDoc(doc(admin(), "flights/flt-mali"))));

  it("client write denied (admin)", () =>
    assertFails(updateDoc(doc(admin(), "flights/flt-mali"), { status: "completed" })));
});

// ─── weather ──────────────────────────────────────────────────────────────
describe("weather/{docId}", () => {
  it("signed-in user reads", () =>
    assertSucceeds(getDoc(doc(mali(), "weather/current"))));

  it("anon denied", () =>
    assertFails(getDoc(doc(anon(), "weather/current"))));

  it("client write denied (admin)", () =>
    assertFails(setDoc(doc(admin(), "weather/current"), {
      state: "storm",
      updatedAt: 1,
      updatedBy: "admin-aok",
    })));
});

// ─── deny-all fallback ────────────────────────────────────────────────────
describe("unknown collection", () => {
  it("user read denied", () =>
    assertFails(getDoc(doc(mali(), "totally_new/foo"))));

  it("admin write denied", () =>
    assertFails(setDoc(doc(admin(), "totally_new/foo"), { x: 1 })));
});
