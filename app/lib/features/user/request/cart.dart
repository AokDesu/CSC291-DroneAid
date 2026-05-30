// Cart state for P-U-03. StateNotifierProvider keeps the cart local to the
// page (not persisted across app launches — per spec, the request is sealed
// at submit time and lives in `requests/`).
//
// Holds a `Map<catalogId, qty>` plus an optional delivery pin override.
// Pure helpers do all the math so they can be exercised by widget tests
// without spinning up Firebase or the map widget.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'catalog.dart';

const maxPayloadKg = 6.0;
const maxQtyPerLine = 10;

@immutable
class CartLineItem {
  const CartLineItem({required this.catalogId, required this.qty});
  final String catalogId;
  final int qty;
}

@immutable
class DeliveryPin {
  const DeliveryPin({required this.lat, required this.lng, this.label});
  final double lat;
  final double lng;
  final String? label;

  LatLng get latLng => LatLng(lat, lng);
}

@immutable
class CartState {
  const CartState({
    this.lines = const {},
    this.pin,
    this.priority = 'normal',
  });
  final Map<String, int> lines;
  final DeliveryPin? pin;
  final String priority; // 'normal' | 'urgent'

  CartState copyWith({
    Map<String, int>? lines,
    DeliveryPin? pin,
    bool clearPin = false,
    String? priority,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      pin: clearPin ? null : (pin ?? this.pin),
      priority: priority ?? this.priority,
    );
  }

  bool get isEmpty => lines.values.fold<int>(0, (a, b) => a + b) == 0;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void setQty(String catalogId, int qty) {
    final next = Map<String, int>.from(state.lines);
    if (qty <= 0) {
      next.remove(catalogId);
    } else {
      next[catalogId] = qty.clamp(1, maxQtyPerLine);
    }
    state = state.copyWith(lines: next);
  }

  void remove(String catalogId) => setQty(catalogId, 0);

  void setPin(DeliveryPin pin) {
    state = state.copyWith(pin: pin);
  }

  void setPriority(String priority) {
    state = state.copyWith(priority: priority);
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

// ─── Pure helpers ───────────────────────────────────────────────────────

/// Compute total weight of the cart against the live catalog. Missing
/// catalog ids contribute 0 (lets the UI show the row but the server
/// rejects on submit, so we never miscount silently).
double cartTotalWeightKg(
  CartState cart,
  List<CatalogEntry> catalog,
) {
  final byId = {for (final c in catalog) c.id: c};
  double total = 0;
  cart.lines.forEach((id, qty) {
    final entry = byId[id];
    if (entry != null) total += entry.weightKg * qty;
  });
  return total;
}

/// Submit-button gate. The UI mirrors this in helper text; the server still
/// does the authoritative check (weight + stock + active) on every call.
bool canSubmit({
  required CartState cart,
  required double totalWeightKg,
  required bool pinSet,
}) {
  if (cart.isEmpty) return false;
  if (totalWeightKg > maxPayloadKg) return false;
  if (!pinSet) return false;
  return true;
}

/// Build the `submitRequest` payload — matches the Zod schema in
/// `functions/src/callable/submitRequest.ts`.
Map<String, dynamic> buildSubmitPayload({
  required CartState cart,
  required DeliveryPin pin,
}) {
  final items = cart.lines.entries
      .map((e) => {'catalogId': e.key, 'qty': e.value})
      .toList(growable: false);
  final addr = <String, dynamic>{'lat': pin.lat, 'lng': pin.lng};
  final label = pin.label?.trim();
  if (label != null && label.isNotEmpty) addr['label'] = label;
  return {
    'items': items,
    'deliveryAddress': addr,
    'priority': cart.priority,
  };
}
