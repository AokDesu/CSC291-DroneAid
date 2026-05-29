// Riverpod providers + pure helpers for P-A-01 admin requests list.
//
// `adminAllRequestsProvider` streams every request doc (admin reads all
// per firestore.rules) ordered by createdAt desc. Composite index already
// exists (createdAt desc on requests, see firestore.indexes.json).
//
// `userNamesProvider` streams `users/` → `{uid: name}` map so the list
// rows can show "Mali Suwan" instead of a raw uid. Admin reads all users
// per firestore.rules.
//
// `filterRequests` + `statusMatchesFilter` are pure helpers extracted for
// unit-testability.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import 'admin_request.dart';

final adminAllRequestsProvider =
    StreamProvider.autoDispose<List<AdminRequest>>((ref) {
  ref.watch(authStateProvider);
  final col = FirebaseFirestore.instance.collection('requests');
  return col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map(AdminRequest.fromSnap).toList(growable: false),
      );
});

/// Streams a single `requests/{reqId}` doc for the P-A-02 detail page.
/// Emits null when the doc disappears mid-session.
final adminRequestDocProvider =
    StreamProvider.autoDispose.family<AdminRequest?, String>((ref, reqId) {
  ref.watch(authStateProvider);
  final docRef = FirebaseFirestore.instance.doc('requests/$reqId');
  return docRef.snapshots().map((snap) {
    if (!snap.exists) return null;
    return AdminRequest.fromSnap(snap);
  });
});

final userNamesProvider =
    StreamProvider.autoDispose<Map<String, String>>((ref) {
  ref.watch(authStateProvider);
  final col = FirebaseFirestore.instance.collection('users');
  return col.snapshots().map(
        (snap) => <String, String>{
          for (final d in snap.docs)
            d.id: (d.data()['name'] as String?) ?? d.id,
        },
      );
});

// ─── Filter chip vocabulary ─────────────────────────────────────────────

/// Filter-chip enum surfaced on P-A-01 per issue #16 AC.
enum AdminRequestFilter {
  all,
  pending,
  approved,
  inFlight,
  completed,
  cancelled,
  rejected,
  aborted,
}

extension AdminRequestFilterLabel on AdminRequestFilter {
  String get label {
    switch (this) {
      case AdminRequestFilter.all:
        return 'All';
      case AdminRequestFilter.pending:
        return 'Pending';
      case AdminRequestFilter.approved:
        return 'Approved';
      case AdminRequestFilter.inFlight:
        return 'In flight';
      case AdminRequestFilter.completed:
        return 'Completed';
      case AdminRequestFilter.cancelled:
        return 'Cancelled';
      case AdminRequestFilter.rejected:
        return 'Rejected';
      case AdminRequestFilter.aborted:
        return 'Aborted';
    }
  }
}

/// Returns true when [status] belongs in the bucket selected by [filter].
/// "Approved" intentionally includes the transient `assigned` state so an
/// approved-but-waiting-for-takeoff request doesn't vanish between chips.
/// "Completed" groups `completed`, `confirmed` (user confirmed receipt),
/// and `delivered` (en-route to confirm) — admin view treats these as
/// done-or-near-done.
bool statusMatchesFilter(String status, AdminRequestFilter filter) {
  switch (filter) {
    case AdminRequestFilter.all:
      return true;
    case AdminRequestFilter.pending:
      return status == 'pending';
    case AdminRequestFilter.approved:
      return status == 'approved' || status == 'assigned';
    case AdminRequestFilter.inFlight:
      return status == 'in_flight';
    case AdminRequestFilter.completed:
      return status == 'completed' ||
          status == 'confirmed' ||
          status == 'delivered';
    case AdminRequestFilter.cancelled:
      return status == 'cancelled';
    case AdminRequestFilter.rejected:
      return status == 'rejected';
    case AdminRequestFilter.aborted:
      return status == 'aborted' || status == 'failed';
  }
}

/// Apply filter chip + free-text search to the admin requests list.
///
/// Search matches case-insensitively against:
///   - reqId substring,
///   - userId substring,
///   - resolved user name substring (when present in [userNames]).
List<AdminRequest> filterRequests(
  List<AdminRequest> all, {
  required AdminRequestFilter filter,
  required String search,
  required Map<String, String> userNames,
}) {
  final q = search.trim().toLowerCase();
  return all.where((r) {
    if (!statusMatchesFilter(r.status, filter)) return false;
    if (q.isEmpty) return true;
    final name = (userNames[r.userId] ?? '').toLowerCase();
    return r.id.toLowerCase().contains(q) ||
        r.userId.toLowerCase().contains(q) ||
        name.contains(q);
  }).toList(growable: false);
}
