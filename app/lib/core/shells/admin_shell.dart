// Admin shell: branded AppBar + top TabBar around admin pages.
// Spec: docs/09-page-flow-design.md §3 (admin shell). Visual reference:
// docs/prototype-screens/admin/P-A-01_admin_requests.png.
//
// Top tabs: Requests · Drones · Control · More (4-tab bar, matches PNG).
// The "More" tab opens a bottom sheet exposing Reports / Weather / Inventory /
// Profile so secondary destinations stay one tap away.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import '../widgets/app_bar_action.dart';
import '../widgets/brand_mark.dart';
import '../widgets/notification_bell.dart';
import '../widgets/role_pill.dart';
import '../widgets/weather_chip.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell>
    with SingleTickerProviderStateMixin {
  static const _tabs = <_AdminTabSpec>[
    _AdminTabSpec(route: '/admin/requests', label: 'Requests', icon: Icons.assignment_outlined),
    _AdminTabSpec(route: '/admin/drones',   label: 'Drones',   icon: Icons.flight_outlined),
    _AdminTabSpec(route: '/admin/control',  label: 'Control',  icon: Icons.map_outlined),
  ];

  late final TabController _controller;

  /// True while a programmatic `animateTo` is running (deep-link sync,
  /// More-sheet fallback). The TabController listener fires on every
  /// index change — user-tapped AND programmatic — and we only want
  /// the user-tap branch to navigate.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // 3 primary tabs + "More" sheet trigger.
    _controller = TabController(length: _tabs.length + 1, vsync: this);
    _controller.addListener(_onTabSelected);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabSelected);
    _controller.dispose();
    super.dispose();
  }

  void _onTabSelected() {
    if (!_controller.indexIsChanging) return;
    if (_syncing) {
      _syncing = false;
      return;
    }
    final i = _controller.index;
    if (i == _tabs.length) {
      _showMoreSheet();
      final fallback = _primaryIndexFor(GoRouterState.of(context).matchedLocation);
      _syncing = true;
      _controller.animateTo(fallback);
      return;
    }
    final route = _tabs[i].route;
    if (GoRouterState.of(context).matchedLocation != route) {
      context.go(route);
    }
  }

  int _primaryIndexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final primaryIndex = _primaryIndexFor(location);
    if (_controller.index != primaryIndex &&
        !_controller.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncing = true;
        _controller.animateTo(primaryIndex);
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: const _AdminTitle(),
        actions: [
          AppBarAction(
            tooltip: 'Weather',
            onTap: () => context.go('/admin/weather'),
            child: const WeatherChipGlyph(size: 16),
          ),
          const SizedBox(width: 6),
          AppBarAction(
            tooltip: 'Notifications',
            onTap: () => context.go('/admin/notifications'),
            child: const NotificationBellGlyph(size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: false,
          tabs: [
            for (final t in _tabs)
              Tab(
                icon: Icon(t.icon, size: 18),
                iconMargin: const EdgeInsets.only(bottom: 4),
                text: t.label,
              ),
            const Tab(
              icon: Icon(Icons.more_horiz, size: 18),
              iconMargin: EdgeInsets.only(bottom: 4),
              text: 'More',
            ),
          ],
        ),
      ),
      body: widget.child,
    );
  }

  Future<void> _showMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Reports'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/admin/reports');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Weather'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/admin/weather');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Inventory'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/admin/inventory');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/admin/profile');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _AdminTitle extends StatelessWidget {
  const _AdminTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: BrandMark(size: 18)),
        SizedBox(width: 6),
        RolePill(role: 'Admin', dense: true),
      ],
    );
  }
}

class _AdminTabSpec {
  const _AdminTabSpec({
    required this.route,
    required this.label,
    required this.icon,
  });
  final String route;
  final String label;
  final IconData icon;
}
