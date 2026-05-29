// Shared AppBar notification bell with unread-count badge.
// Streams users/{uid}/notifications via notificationsProvider and renders a
// red dot badge when any unread notifications exist. Tap routes to the
// notifications page inside the user's CURRENT shell — admins land on
// /admin/notifications (inside AdminShell), users on /user/notifications.
//
// Spec: docs/09-page-flow-design.md §3 (shell AppBar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/user/notifications/notifications_provider.dart';
import '../auth/auth_providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final unread = async.valueOrNull?.where((n) => n.isUnread).length ?? 0;
    final route = (profile?.isAdmin ?? false)
        ? '/admin/notifications'
        : '/user/notifications';

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.go(route),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
