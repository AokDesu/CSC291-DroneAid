// Idempotent seed for catalog/* per design-spec §4.3.

import { db } from "../lib/admin";

interface SeedItem {
  itemId: string;
  name: string;
  weightKg: number;
  stock: number;
  icon: string;
  active: boolean;
}

const ITEMS: SeedItem[] = [
  { itemId: "food-kit",     name: "Food Kit",              weightKg: 2.0, stock: 30, icon: "food",    active: true },
  { itemId: "water-5l",     name: "Water 5 L",             weightKg: 5.0, stock: 20, icon: "water",   active: true },
  { itemId: "medical-kit",  name: "Medical Kit",           weightKg: 1.0, stock: 15, icon: "med",     active: true },
  { itemId: "baby-formula", name: "Baby Formula",          weightKg: 1.2, stock: 12, icon: "baby",    active: true },
  { itemId: "blanket",      name: "Blanket",               weightKg: 0.5, stock: 25, icon: "blanket", active: true },
  { itemId: "flashlight",   name: "Flashlight + batteries", weightKg: 0.4, stock: 10, icon: "light",  active: true },
];

export async function seedCatalog(): Promise<void> {
  const batch = db.batch();
  for (const it of ITEMS) {
    const { itemId, ...rest } = it;
    batch.set(db.doc(`catalog/${itemId}`), rest, { merge: true });
  }
  await batch.commit();
  console.log(`seedCatalog: wrote ${ITEMS.length} items.`);
}
