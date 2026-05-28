// Riverpod providers + domain model for users/{uid}/notifications subcollection.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String deepLink;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data();
    return AppNotification(
      id: snap.id,
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      deepLink: (d['deepLink'] as String?) ?? '/',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (d['readAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Streams all notifications for the signed-in user, newest first.
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('users/${user.uid}/notifications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(AppNotification.fromSnap)
            .toList(growable: false),
      );
});
