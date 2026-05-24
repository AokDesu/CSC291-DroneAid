// Admin-side projection of `requests/{reqId}` for P-A-01 + P-A-02. Mirrors
// the shape created by `functions/src/callable/submitRequest.ts` and
// surfaces the extra fields the admin views need (userId, delivery
// address, decision metadata) on top of the user-side queue model.

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRequestItem {
  const AdminRequestItem({required this.catalogId, required this.qty});
  final String catalogId;
  final int qty;
}

class AdminRequest {
  const AdminRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.items,
    required this.totalWeightKg,
    required this.createdAt,
    this.priority = 'normal',
    this.deliveryLabel,
    this.deliveryLat,
    this.deliveryLng,
    this.currentFlightId,
    this.rejectReason,
  });

  final String id;
  final String userId;
  final String status;
  final List<AdminRequestItem> items;
  final double totalWeightKg;
  final DateTime? createdAt;
  final String priority;
  final String? deliveryLabel;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? currentFlightId;
  final String? rejectReason;

  factory AdminRequest.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => AdminRequestItem(
            catalogId: (m['catalogId'] as String?) ?? '',
            qty: (m['qty'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
    final addr = (data['deliveryAddress'] as Map?)?.cast<String, dynamic>();
    return AdminRequest(
      id: snap.id,
      userId: (data['userId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      items: items,
      totalWeightKg: (data['totalWeightKg'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      priority: (data['priority'] as String?) ?? 'normal',
      deliveryLabel: addr?['label'] as String?,
      deliveryLat: (addr?['lat'] as num?)?.toDouble(),
      deliveryLng: (addr?['lng'] as num?)?.toDouble(),
      currentFlightId: data['currentFlightId'] as String?,
      rejectReason: data['rejectReason'] as String?,
    );
  }
}
