// P-U-08 Notifications — in-app inbox.
// Spec: docs/09-page-flow-design.md §5 P-U-08.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'notifications/notifications_provider.dart';
import 'request/app_request.dart' show relativeTime;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _markRead(String uid, String nid) async {
    await FirebaseFirestore.instance
        .doc('users/$uid/notifications/$nid')
        .update({'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = notifications[i];
              return ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: n.isUnread
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight:
                        n.isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      relativeTime(n.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () async {
                  if (n.isUnread) await _markRead(uid, n.id);
                  if (context.mounted) context.go(n.deepLink);
                },
              );
            },
          );
        },
      ),
    );
  }
}
