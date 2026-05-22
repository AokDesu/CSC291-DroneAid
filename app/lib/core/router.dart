// go_router skeleton per docs/09-page-flow-design.md §3.
// Belle owns the auth gate; until that lands, every route is reachable for
// development. Routes match the IDs in the page-flow design doc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/user/home_page.dart';
import '../features/admin/requests_page.dart';

/// Single source of truth for navigation. Watched by [DroneAidApp].
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      // User shell (placeholder; bottom-nav added when Belle implements AuthGate).
      GoRoute(path: '/user/home',           builder: (_, __) => const UserHomePage()),
      GoRoute(path: '/user/queue',          builder: (_, __) => const _Placeholder('Queue (P-U-04)')),
      GoRoute(
        path: '/user/tracking/:flightId',
        builder: (_, state) =>
            _Placeholder('Tracking flight ${state.pathParameters['flightId']} (P-U-05)'),
      ),
      GoRoute(
        path: '/user/confirm/:reqId',
        builder: (_, state) =>
            _Placeholder('Confirm request ${state.pathParameters['reqId']} (P-U-06)'),
      ),
      GoRoute(path: '/user/history',        builder: (_, __) => const _Placeholder('History (P-U-07)')),
      GoRoute(path: '/user/notifications',  builder: (_, __) => const _Placeholder('Notifications (P-U-08)')),
      GoRoute(path: '/user/profile',        builder: (_, __) => const _Placeholder('Profile + Settings (P-U-09)')),

      // Admin
      GoRoute(path: '/admin/requests',      builder: (_, __) => const AdminRequestsPage()),
      GoRoute(
        path: '/admin/requests/:reqId',
        builder: (_, state) =>
            _Placeholder('Request manage ${state.pathParameters['reqId']} (P-A-02)'),
      ),
      GoRoute(path: '/admin/drones',        builder: (_, __) => const _Placeholder('Drone list (P-A-03)')),
      GoRoute(
        path: '/admin/drones/:droneId',
        builder: (_, state) =>
            _Placeholder('Drone ${state.pathParameters['droneId']} (P-A-04)'),
      ),
      GoRoute(path: '/admin/control',       builder: (_, __) => const _Placeholder('Control map (P-A-05)')),
      GoRoute(path: '/admin/weather',       builder: (_, __) => const _Placeholder('Weather panel (P-A-06)')),
      GoRoute(path: '/admin/inventory',     builder: (_, __) => const _Placeholder('Inventory (P-A-07)')),
    ],
    errorBuilder: (_, state) => _Placeholder('No route for ${state.uri.path}'),
  );
});

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DroneAid (placeholder)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
