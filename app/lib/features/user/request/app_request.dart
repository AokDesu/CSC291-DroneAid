// Domain model for `requests/{reqId}` docs.
// Mirrors the shape created by `functions/src/callable/submitRequest.ts` and
// mutated by approveRequest, rejectRequest, assignDrone, cancelRequest,
// confirmDelivery, and the onFlightWritten trigger.
//
// Status state machine (design-spec §8 + §10):
//   pending → approved → assigned → in_flight → delivered → confirmed
//                    ↘ rejected            ↘ failed
//                                          ↘ aborted
//   pending → cancelled (user)

import 'package:cloud_firestore/cloud_firestore.dart';

/// Section buckets shown on P-U-04. `hidden` items live in P-U-07 History.
enum QueueBucket { pending, active, hidden }

class RequestItemLine {
  const RequestItemLine({required this.catalogId, required this.qty});
  final String catalogId;
  final int qty;
}

class AppRequest {
  const AppRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.items,
    required this.totalWeightKg,
    required this.createdAt,
    this.currentFlightId,
  });

  final String id;
  final String userId;
  final String status;
  final List<RequestItemLine> items;
  final double totalWeightKg;
  final DateTime? createdAt;
  final String? currentFlightId;

  factory AppRequest.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => RequestItemLine(
            catalogId: (m['catalogId'] as String?) ?? '',
            qty: (m['qty'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
    return AppRequest(
      id: snap.id,
      userId: (data['userId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      items: items,
      totalWeightKg: (data['totalWeightKg'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      currentFlightId: data['currentFlightId'] as String?,
    );
  }

  QueueBucket get bucket => bucketFor(status);
}

/// Pure helper — maps a status string to the P-U-04 section bucket.
/// See spec §5 P-U-04 "Sections".
QueueBucket bucketFor(String status) {
  switch (status) {
    case 'pending':
      return QueueBucket.pending;
    case 'approved':
    case 'assigned':
    case 'in_flight':
    case 'delivered':
      return QueueBucket.active;
    default:
      // rejected, cancelled, failed, aborted, confirmed, completed → History.
      return QueueBucket.hidden;
  }
}

/// Pure helper — human-friendly relative time like "Just now", "7 min ago",
/// "3 h ago", "Yesterday", "Mar 14". Pure for testability.
String relativeTime(DateTime? when, {DateTime? now}) {
  if (when == null) return '—';
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.isNegative) return 'Just now';
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  // Older than a week — drop to a calendar date. Kept locale-naive on
  // purpose; intl formatting can be layered on later without breaking tests.
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}';
}
