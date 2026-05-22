// Run every seed in order. Idempotent — safe to re-run.
//
// Usage:
//   npm run build
//   node lib/seed/seedAll.js
//
// Or against the emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 \
//   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
//   node lib/seed/seedAll.js

import { seedCatalog } from "./seedCatalog";
import { seedDrones } from "./seedDrones";
import { seedAdmins } from "./seedAdmins";
import { seedDemoUsers } from "./seedDemoUsers";
import { seedWeather } from "./seedWeather";

async function main(): Promise<void> {
  await seedCatalog();
  await seedDrones();
  await seedAdmins();
  await seedDemoUsers();
  await seedWeather();
  console.log("All seeds applied.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
