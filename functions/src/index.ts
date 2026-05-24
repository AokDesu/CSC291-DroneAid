// DroneAid Cloud Functions barrel.
//
// Region pinned to asia-southeast1 (Singapore) for proximity to Thai users.
//
// Engineer rule: every callable validates auth + role inside its handler;
// every state-changing path goes through these functions, never direct client
// writes (see firestore.rules and design-spec §9).

import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({
  region: "asia-southeast1",
  maxInstances: 10,
});

// ── Callable functions (user) ───────────────────────────────────────────
export { submitRequest } from "./callable/submitRequest";
export { cancelRequest } from "./callable/cancelRequest";
export { confirmDelivery } from "./callable/confirmDelivery";
export { updateProfile } from "./callable/updateProfile";

// ── Callable functions (admin) ──────────────────────────────────────────
export { approveRequest } from "./callable/approveRequest";
export { rejectRequest } from "./callable/rejectRequest";
export { assignDrone } from "./callable/assignDrone";
export { setWeather } from "./callable/setWeather";
export { restockItem } from "./callable/restockItem";
export { toggleDroneMaintenance } from "./callable/toggleDroneMaintenance";
export { createCatalogItem } from "./callable/createCatalogItem";
export { toggleCatalogActive } from "./callable/toggleCatalogActive";

// ── Scheduled ───────────────────────────────────────────────────────────
export { tickFlights } from "./scheduled/tickFlights";

// ── Triggers ────────────────────────────────────────────────────────────
export { onUserCreated } from "./triggers/onUserCreated";
export { onFlightWritten } from "./triggers/onFlightWritten";
