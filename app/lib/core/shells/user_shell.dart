// User shell: persistent AppBar + NavigationBar around user-side pages.
// Spec: docs/09-page-flow-design.md §3 (user shell).
//
// Tabs: Home · Queue · Tracking · History · Profile.
// Tracking tab is dimmed when the signed-in user has no active flight; tapping
// the dimmed tab shows a snackbar instead of navigating (per spec).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/user/request/app_request.dart';
import '../../features/user/request/queue_provider.dart';
import '../auth/auth_providers.dart';
import '../widgets/notification_bell.dart';
import '../widgets/weather_chip.dart';

class UserShell extends ConsumerWidget {
  const UserShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec(route: '/user/home',    label: 'Home',     icon: Icons.home_outlined,         selectedIcon: Icons.home),
    _TabSpec(route: '/user/queue',   label: 'Queue',    icon: Icons.list_alt,              selectedIcon: Icons.list_alt),
    _TabSpec(route: '/user/tracking',label: 'Tracking', icon: Icons.flight_outlined,       selectedIcon: Icons.flight),
    _TabSpec(route: '/user/history', label: 'History',  icon: Icons.history,               selectedIcon: Icons.history),
    _TabSpec(route: '/user/profile', label: 'Profile',  icon: Icons.person_outline,        selectedIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndexFor(location);

    final activeFlightId = ref.watch(activeFlightIdProvider);
    final hasActiveFlight = activeFlightId != null;

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final initials = _initials(profile?.name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DroneAid'),
        actions: [
          const WeatherChip(),
          const NotificationBell(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go('/user/profile'),
            icon: CircleAvatar(
              radius: 14,
              child: Text(
                initials,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          final tab = _tabs[i];
          if (tab.route == '/user/tracking') {
            if (!hasActiveFlight) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "You don't have a drone in flight right now.",
                  ),
                ),
              );
              return;
            }
            context.go('/user/tracking/$activeFlightId');
            return;
          }
          context.go(tab.route);
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(
                tab.icon,
                color: tab.route == '/user/tracking' && !hasActiveFlight
                    ? Theme.of(context).disabledColor
                    : null,
              ),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  int _selectedIndexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _TabSpec {
  const _TabSpec({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Resolves the user's most recent in-flight request to a flight id (if any),
/// so the Tracking tab can deep-link straight to that flight. Returns null
/// when the user has no in-flight requests or is signed out.
final activeFlightIdProvider = Provider<String?>((ref) {
  final async = ref.watch(myRequestsProvider);
  final list = async.valueOrNull ?? const <AppRequest>[];
  for (final r in list) {
    if (r.status == 'in_flight' && r.currentFlightId != null) {
      return r.currentFlightId;
    }
  }
  return null;
});
