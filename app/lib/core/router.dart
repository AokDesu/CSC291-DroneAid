// go_router with role-aware redirect guard. See docs/09-page-flow-design.md §3.
//
// Layout:
//   - Public routes (/login, /register) live outside any shell.
//   - User pages live inside [UserShell] (AppBar + bottom NavigationBar).
//   - Admin pages live inside [AdminShell] (AppBar + top TabBar + More sheet).
//   - Detail / full-screen pages (tracking, confirm, request detail, drone
//     detail) live outside both shells so they render edge-to-edge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/control_page.dart';
import '../features/admin/drones/drone_detail_page.dart';
import '../features/admin/drones_page.dart';
import '../features/admin/inventory_page.dart';
import '../features/admin/requests/admin_request_detail_page.dart';
import '../features/admin/requests_page.dart';
import '../features/admin/weather_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/user/confirm_page.dart';
import '../features/user/history_page.dart';
import '../features/user/home_page.dart';
import '../features/user/notifications_page.dart';
import '../features/user/profile_page.dart';
import '../features/user/queue_page.dart';
import '../features/user/tracking_page.dart';
import 'auth/auth_providers.dart';
import 'shells/admin_shell.dart';
import 'shells/user_shell.dart';

const _publicRoutes = {'/login', '/register'};

/// Single source of truth for navigation. Watched by [DroneAidApp].
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(userProfileProvider);
      final loc = state.matchedLocation;
      final isPublic = _publicRoutes.contains(loc);

      // Still resolving cold-start auth — let splash render.
      if (auth.isLoading) return null;

      final user = auth.valueOrNull;
      if (user == null) {
        return isPublic ? null : '/login';
      }

      // Signed in but profile not yet loaded — keep on splash, redirect later.
      if (profile.isLoading) return isPublic ? null : null;

      final role = profile.valueOrNull?.role ?? 'user';
      final landing = role == 'admin' ? '/admin/requests' : '/user/home';

      if (isPublic) return landing;
      if (loc.startsWith('/admin') && role != 'admin') return '/user/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      // ── User shell (bottom nav + AppBar) ────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => UserShell(child: child),
        routes: [
          GoRoute(path: '/user/home',          builder: (_, __) => const UserHomePage()),
          GoRoute(path: '/user/queue',         builder: (_, __) => const QueuePage()),
          GoRoute(path: '/user/history',       builder: (_, __) => const HistoryPage()),
          GoRoute(path: '/user/notifications', builder: (_, __) => const NotificationsPage()),
          GoRoute(path: '/user/profile',       builder: (_, __) => const ProfilePage()),
        ],
      ),

      // ── Admin shell (top tabs + AppBar + More sheet) ────────────────────
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin/requests',  builder: (_, __) => const AdminRequestsPage()),
          GoRoute(path: '/admin/drones',    builder: (_, __) => const AdminDronesPage()),
          GoRoute(path: '/admin/control',   builder: (_, __) => const ControlPage()),
          GoRoute(path: '/admin/weather',   builder: (_, __) => const AdminWeatherPage()),
          GoRoute(path: '/admin/inventory', builder: (_, __) => const AdminInventoryPage()),
          GoRoute(path: '/admin/profile',   builder: (_, __) => const ProfilePage()),
        ],
      ),

      // ── Full-screen / detail routes (outside any shell) ─────────────────
      GoRoute(
        path: '/user/tracking/:flightId',
        builder: (_, state) => TrackingPage(
          flightId: state.pathParameters['flightId']!,
        ),
      ),
      GoRoute(
        path: '/user/confirm/:reqId',
        builder: (_, state) => ConfirmPage(
          reqId: state.pathParameters['reqId']!,
        ),
      ),
      GoRoute(
        path: '/admin/requests/:reqId',
        builder: (_, state) => AdminRequestDetailPage(
          reqId: state.pathParameters['reqId']!,
        ),
      ),
      GoRoute(
        path: '/admin/drones/:droneId',
        builder: (_, state) => AdminDroneDetailPage(
          droneId: state.pathParameters['droneId']!,
        ),
      ),
    ],
    errorBuilder: (_, __) => const _Placeholder(),
  );
});

/// Bridges Riverpod's [authStateProvider] + [userProfileProvider] into the
/// [GoRouter.refreshListenable] hook so the redirect re-runs on sign-in/out.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _authSub = _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _profileSub = _ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription _authSub;
  late final ProviderSubscription _profileSub;

  @override
  void dispose() {
    _authSub.close();
    _profileSub.close();
    super.dispose();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "We couldn't find what you were looking for.",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
