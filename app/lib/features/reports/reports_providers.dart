// Riverpod stream providers for Reports.
//
// - `adminOpenReportsProvider` — collectionGroup('reports') filtered to
//   status==open, ordered by createdAt desc. Backed by the
//   firestore.indexes.json collectionGroup index. Admin queue.
// - `requestReportsProvider.family(reqId)` — all Reports on a single
//   Request, ordered by createdAt desc. Used by:
//     * admin_request_detail_page (Reports section)
//     * history_page detail sheet (Report-status chip + filing gate)
//
// Read scope is enforced server-side by firestore.rules — owner reads
// own request's reports, admin reads all.
//
// Both providers watch authStateProvider so the underlying Firestore
// listener is recreated on sign-out / sign-in. Without this, a
// permission-denied error captured during a previous (non-admin)
// session would stick in Riverpod's AsyncError cache until app
// restart. autoDispose tears the stream down when no widget watches.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'report.dart';

final adminOpenReportsProvider =
    StreamProvider.autoDispose<List<Report>>((ref) {
  ref.watch(authStateProvider);
  final query = FirebaseFirestore.instance
      .collectionGroup('reports')
      .where('status', isEqualTo: 'open')
      .orderBy('createdAt', descending: true);
  return query.snapshots().map(
        (snap) => snap.docs.map(Report.fromSnap).toList(growable: false),
      );
});

final requestReportsProvider =
    StreamProvider.autoDispose.family<List<Report>, String>((ref, reqId) {
  ref.watch(authStateProvider);
  final col = FirebaseFirestore.instance.collection('requests/$reqId/reports');
  return col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map(Report.fromSnap).toList(growable: false),
      );
});
