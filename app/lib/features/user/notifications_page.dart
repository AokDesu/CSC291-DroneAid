// P-U-08 Notifications — in-app inbox.
// Spec: docs/09-page-flow-design.md §5 P-U-08.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_errors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_placeholder.dart';
import 'notifications/notifications_provider.dart';
import 'request/app_request.dart' show relativeTime;

/// One-shot existence check for a deepLink destination, so a stale
/// notification doesn't navigate the user to a "not found" page.
/// Returns true for routes that don't depend on a per-resource doc.
Future<bool> _destinationExists(String deepLink) async {
  final reqMatch =
      RegExp(r'^/(?:user/confirm|admin/requests)/([^/]+)$').firstMatch(deepLink);
  if (reqMatch != null) {
    final snap = await FirebaseFirestore.instance
        .doc('requests/${reqMatch.group(1)}')
        .get();
    return snap.exists;
  }
  final flightMatch =
      RegExp(r'^/(?:user/tracking|admin/drones)/([^/]+)$').firstMatch(deepLink);
  if (flightMatch != null) {
    final coll = deepLink.startsWith('/user/tracking') ? 'flights' : 'drones';
    final snap = await FirebaseFirestore.instance
        .doc('$coll/${flightMatch.group(1)}')
        .get();
    return snap.exists;
  }
  // List/index routes (e.g. /admin/reports, /user/history) are always valid.
  return true;
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _markRead(String uid, String nid) async {
    await FirebaseFirestore.instance
        .doc('users/$uid/notifications/$nid')
        .update({'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> _markAllRead(
    BuildContext context,
    String uid,
    List<AppNotification> notifications,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final unread = notifications.where((n) => n.isUnread).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(
        FirebaseFirestore.instance.doc('users/$uid/notifications/${n.id}'),
        {'readAt': FieldValue.serverTimestamp()},
      );
    }
    try {
      await batch.commit();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Marked ${unread.length} as read.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: async.when(
        loading: () => const LoadingPlaceholder(label: 'Loading notifications…'),
        error: (e, _) => Center(child: Text('Failed to load notifications: ${describeFunctionsError(e)}')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              helper: 'Updates about your drone deliveries will show up here.',
            );
          }
          final hasUnread = notifications.any((n) => n.isUnread);
          return Column(
            children: [
              if (hasUnread)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('mark-all-read'),
                      onPressed: () =>
                          _markAllRead(context, uid, notifications),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark all as read'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
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
                          fontWeight: n.isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            relativeTime(n.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (n.isUnread) await _markRead(uid, n.id);
                        final exists = await _destinationExists(n.deepLink);
                        if (!context.mounted) return;
                        if (!exists) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This notification is no longer available.',
                              ),
                            ),
                          );
                          return;
                        }
                        context.go(n.deepLink);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
