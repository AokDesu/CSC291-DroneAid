// P-A-03 Admin Drone list.
// Spec: docs/09-page-flow-design.md §6 P-A-03.
// Backend: read-only stream of `drones` collection (rules: read any signed-in,
// writes go through toggleDroneMaintenance + tickFlights).
//
// Out of scope this PR: ETA footer for flying drones (needs flight join).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/battery_bar.dart';
import 'drones/drone.dart';
import 'drones/drone_providers.dart';

/// Canonical filter set. Empty selection means "All".
const _statusFilters = <String>[
  'idle',
  'flying',
  'maintenance',
  'offline',
];

/// Per-status display color. Mirrors the prototype palette (P-A-03 doc).
/// Kept inline rather than extending StatusChip — Belle's widget API is
/// frozen (#23 / ADR-0003), and request statuses use a different palette.
Color droneStatusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'idle':
      return Colors.green;
    case 'flying':
      return scheme.primary;
    case 'maintenance':
      return Colors.amber.shade700;
    case 'offline':
      return Colors.grey;
    default:
      return Colors.grey;
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
    default:
      return status;
  }
}

/// Client-side filter. Empty set = no filter.
@visibleForTesting
List<Drone> applyDroneFilter(List<Drone> drones, Set<String> selected) {
  if (selected.isEmpty) return drones;
  return drones.where((d) => selected.contains(d.status)).toList(growable: false);
}

final _droneFilterProvider = StateProvider<Set<String>>((ref) => <String>{});

class AdminDronesPage extends ConsumerWidget {
  const AdminDronesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDronesStreamProvider);
    final selected = ref.watch(_droneFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Drones (P-A-03)')),
      body: Column(
        children: [
          _FilterBar(selected: selected),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load drones: $e')),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(child: Text('No drones yet.'));
                }
                final filtered = applyDroneFilter(all, selected);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No drones in this filter.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _DroneCard(drone: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});
  final Set<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void toggle(String? s) {
      final next = {...selected};
      if (s == null) {
        next.clear();
      } else if (!next.add(s)) {
        next.remove(s);
      }
      ref.read(_droneFilterProvider.notifier).state = next;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            key: const Key('filter-all'),
            label: const Text('All'),
            selected: selected.isEmpty,
            onSelected: (_) => toggle(null),
          ),
          const SizedBox(width: 8),
          for (final s in _statusFilters) ...[
            FilterChip(
              key: Key('filter-$s'),
              label: Text(droneStatusLabel(s)),
              selected: selected.contains(s),
              onSelected: (_) => toggle(s),
            ),
            const SizedBox(width: 8),
          ],
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
    final statusColor = droneStatusColor(drone.status, theme.colorScheme);

    return InkWell(
      key: Key('drone-${drone.id}'),
      onTap: () => context.push('/admin/drones/${drone.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(Icons.flight, color: theme.colorScheme.onPrimary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drone.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'max ${drone.maxPayloadKg.toStringAsFixed(1)} kg',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  key: Key('drone-status-${drone.id}'),
                  label: Text(
                    droneStatusLabel(drone.status),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: BatteryBar(percent: drone.batteryPct.toDouble()),
                ),
                const SizedBox(width: 12),
                Text(
                  '${drone.batteryPct}%',
                  style: theme.textTheme.labelMedium,
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
