// Single source of truth for the themed catalog-icon vocabulary.
// Both admin inventory (picker + row icon) and user home (catalog tile
// icon) read from this list. Adding a new icon means adding one entry
// here; every surface picks it up automatically.

import 'package:flutter/material.dart';

class CatalogIconOption {
  const CatalogIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const catalogIcons = <CatalogIconOption>[
  CatalogIconOption(key: 'food',     label: 'Food',     icon: Icons.restaurant),
  CatalogIconOption(key: 'water',    label: 'Water',    icon: Icons.water_drop),
  CatalogIconOption(key: 'med',      label: 'Medical',  icon: Icons.medical_services),
  CatalogIconOption(key: 'baby',     label: 'Baby',     icon: Icons.child_friendly),
  CatalogIconOption(key: 'blanket',  label: 'Blanket',  icon: Icons.bed),
  CatalogIconOption(key: 'light',    label: 'Light',    icon: Icons.flashlight_on),
  CatalogIconOption(key: 'shelter',  label: 'Shelter',  icon: Icons.cabin),
  CatalogIconOption(key: 'hygiene',  label: 'Hygiene',  icon: Icons.soap),
  CatalogIconOption(key: 'battery',  label: 'Battery',  icon: Icons.battery_full),
  CatalogIconOption(key: 'clothing', label: 'Clothing', icon: Icons.checkroom),
  CatalogIconOption(key: 'radio',    label: 'Radio',    icon: Icons.radio),
  CatalogIconOption(key: 'tools',    label: 'Tools',    icon: Icons.handyman),
  CatalogIconOption(key: 'fuel',     label: 'Fuel',     icon: Icons.local_gas_station),
  CatalogIconOption(key: 'mask',     label: 'Mask',     icon: Icons.masks),
  CatalogIconOption(key: 'docs',     label: 'Docs',     icon: Icons.description),
  CatalogIconOption(key: 'pet',      label: 'Pet',      icon: Icons.pets),
];

/// Looks up the IconData for a stored `icon` key. Unknown / null keys
/// fall through to a generic inventory icon so the row still renders.
IconData resolveCatalogIcon(String? key) {
  for (final o in catalogIcons) {
    if (o.key == key) return o.icon;
  }
  return Icons.inventory_2;
}
