// P-A-03 Admin Drone list.
// Spec: docs/09-page-flow-design.md §6 P-A-03.
// Visual: docs/prototype-screens/admin/P-A-03_drones.png.
// Backend: read-only stream of `drones` collection (rules: read any signed-in,
// writes go through toggleDroneMaintenance + tickFlights).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/battery_bar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/page_header.dart';
import 'drones/drone.dart';
import 'drones/drone_dialogs.dart';
import 'drones/drone_providers.dart';

const _statusFilters = <String>[
  'idle',
  'flying',
  'maintenance',
  'offline',
  'retired',
];

class _DroneStatusPalette {
  const _DroneStatusPalette({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

_DroneStatusPalette droneStatusPalette(String status, AppStatusColors p) {
  switch (status) {
    case 'idle':
      return _DroneStatusPalette(bg: p.confirmedBg, fg: p.confirmedFg);
    case 'flying':
      return _DroneStatusPalette(bg: p.approvedBg, fg: p.approvedFg);
    case 'maintenance':
      return _DroneStatusPalette(bg: p.deliveredBg, fg: p.deliveredFg);
    case 'offline':
      return _DroneStatusPalette(bg: p.cancelledBg, fg: p.cancelledFg);
    case 'retired':
      return _DroneStatusPalette(bg: p.cancelledBg, fg: p.cancelledFg);
    default:
      return _DroneStatusPalette(bg: p.cancelledBg, fg: p.cancelledFg);
  }
}

@Deprecated('Use droneStatusPalette via AppStatusColors ThemeExtension.')
Color droneStatusColor(String status, ColorScheme scheme) {
  // Back-compat shim. Returns a vaguely correct color for any caller still
  // relying on the old API (widget tests reference it).
  switch (status) {
    case 'idle':
      return const Color(0xFF2D8C7F);
    case 'flying':
      return scheme.primary;
    case 'maintenance':
      return const Color(0xFFE0A816);
    case 'offline':
      return const Color(0xFF5B6470);
    case 'retired':
      return const Color(0xFF8B92A0);
    default:
      return const Color(0xFF5B6470);
  }
}

String droneStatusLabel(String status) {
  switch (status) {
    case 'idle':
      return 'Idle';
    case 'flying':
      return 'Flying';
    case 'maintenance':
      return 'Maint.';
    case 'offline':
      return 'Offline';
    case 'retired':
      return 'Retired';
    default:
      return status;
  }
}

@visibleForTesting
List<Drone> applyDroneFilter(List<Drone> drones, Set<String> selected) {
  if (selected.isEmpty) {
    return drones
        .where((d) => d.status != 'retired')
        .toList(growable: false);
  }
  return drones.where((d) => selected.contains(d.status)).toList(growable: false);
}

final _droneFilterProvider = StateProvider<Set<String>>((ref) => <String>{});

class AdminDronesPage extends ConsumerWidget {
  const AdminDronesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDronesStreamProvider);
    final selected = ref.watch(_droneFilterProvider);
    final all = async.valueOrNull ?? const <Drone>[];
    final counts = <String, int>{};
    for (final d in all) {
      counts[d.status] = (counts[d.status] ?? 0) + 1;
    }
    final summary = [
      '${counts['idle'] ?? 0} idle',
      '${counts['flying'] ?? 0} flying',
      '${counts['maintenance'] ?? 0} maint.',
      '${counts['offline'] ?? 0} offline',
    ].join(' · ');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('drones-add-fab'),
        onPressed: () => showAddDroneDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add drone'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load drones: $e',
          onRetry: () => ref.invalidate(adminDronesStreamProvider),
        ),
        data: (_) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                eyebrow: 'P-A-03 · FLEET',
                title: 'Drones',
                subtitle: summary,
              ),
              _FilterBar(selected: selected),
              if (all.isEmpty)
                const EmptyState(
                  icon: Icons.flight,
                  title: 'No drones yet',
                  helper: 'Once the fleet is seeded, drones show up here.',
                )
              else
                () {
                  final filtered = applyDroneFilter(all, selected);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.filter_alt_off,
                      title: 'No drones in this filter',
                      helper: 'Try clearing or changing the status filter above.',
                    );
                  }
                  return Column(
                    children: [
                      for (final d in filtered) _DroneCard(drone: d),
                    ],
                  );
                }(),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});
  final Set<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    void toggle(String? s) {
      final next = {...selected};
      if (s == null) {
        next.clear();
      } else if (!next.add(s)) {
        next.remove(s);
      }
      ref.read(_droneFilterProvider.notifier).state = next;
    }

    Widget chip({
      required Key key,
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: key,
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onTap(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          selectedColor: t.colorScheme.primary.withValues(alpha: 0.18),
          side: BorderSide(color: t.dividerColor),
          labelStyle: TextStyle(
            color: isSelected ? t.colorScheme.primary : t.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          chip(
            key: const Key('filter-all'),
            label: 'All',
            isSelected: selected.isEmpty,
            onTap: () => toggle(null),
          ),
          for (final s in _statusFilters)
            chip(
              key: Key('filter-$s'),
              label: droneStatusLabel(s),
              isSelected: selected.contains(s),
              onTap: () => toggle(s),
            ),
        ],
      ),
    );
  }
}

class _DroneCard extends StatelessWidget {
  const _DroneCard({required this.drone});
  final Drone drone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = droneStatusPalette(drone.status, context.statusColors);
    final tints = context.categoryTints;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2,
      ),
      child: Card(
        child: InkWell(
          key: Key('drone-${drone.id}'),
          onTap: () => context.push('/admin/drones/${drone.id}'),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tints.fallback,
                        borderRadius:
                            BorderRadius.circular(AppRadii.iconTile),
                      ),
                      child: Icon(
                        Icons.flight,
                        size: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drone.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'max ${drone.maxPayloadKg.toStringAsFixed(1)} kg',
                            style: context.appText.mono,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: Key('drone-status-${drone.id}'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.bg,
                        borderRadius:
                            BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.fg,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            droneStatusLabel(drone.status),
                            style: TextStyle(
                              color: palette.fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Row(
                  children: [
                    Expanded(
                      child: BatteryBar(percent: drone.batteryPct.toDouble()),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${drone.batteryPct}%',
                      style: context.appText.monoStrong,
                    ),
                  ],
                ),
                if (drone.currentFlightId != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        drone.currentFlightId!,
                        key: Key('drone-flight-${drone.id}'),
                        style: context.appText.requestId,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
