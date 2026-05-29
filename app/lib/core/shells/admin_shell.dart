// Admin shell: AppBar + top TabBar around admin pages.
// Spec: docs/09-page-flow-design.md §3 (admin shell).
//
// Top tabs: Requests · Drones · Control · More.
// The "More" tab opens a bottom sheet exposing Weather / Inventory / Profile,
// matching the design's secondary-nav drawer behaviour.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/notification_bell.dart';
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
    _AdminTabSpec(route: '/admin/requests', label: 'Requests', icon: Icons.assignment),
    _AdminTabSpec(route: '/admin/drones',   label: 'Drones',   icon: Icons.flight),
    _AdminTabSpec(route: '/admin/control',  label: 'Control',  icon: Icons.map),
  ];

  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    // 4 tabs total: 3 primary destinations + "More" sheet trigger.
    _controller = TabController(length: 4, vsync: this);
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
    final i = _controller.index;
    if (i == 3) {
      // "More" — pop sheet, snap selection back to the active primary tab.
      _showMoreSheet();
      final fallback = _primaryIndexFor(GoRouterState.of(context).matchedLocation);
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
      // Sync underline to the currently active route (e.g. after deep link).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.animateTo(primaryIndex);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DroneAid · Admin'),
        actions: [
          const WeatherChip(),
          const NotificationBell(),
          IconButton(
            tooltip: 'Weather settings',
            onPressed: () => context.go('/admin/weather'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _controller,
          tabs: [
            for (final t in _tabs)
              Tab(icon: Icon(t.icon), text: t.label),
            const Tab(icon: Icon(Icons.more_horiz), text: 'More'),
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
