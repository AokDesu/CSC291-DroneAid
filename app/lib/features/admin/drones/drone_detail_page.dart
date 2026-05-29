// P-A-04 Admin Drone detail.
// Spec: docs/09-page-flow-design.md §6 P-A-04.
// Backend: read drone doc; writes via `toggleDroneMaintenance` callable, which
// itself refuses when the drone is in flight.
//
// Out of scope this PR: current-flight panel + recent-flights list (depend on
// the Flight model + an index; will land alongside Poom's tracking work).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/battery_bar.dart';
import '../../user/tracking/flight_provider.dart' show flightStreamProvider;
import '../drones_page.dart' show droneStatusColor, droneStatusLabel;
import 'drone.dart';
import 'drone_dialogs.dart';
import 'drone_providers.dart';

const _functionsRegion = 'asia-southeast1';

/// Pure helper — short "X ago" relative time. Returns '—' for null.
/// Kept simple and inline; `intl` is on the dep list but we don't need the
/// full DateFormat machinery for one readout.
@visibleForTesting
String relativeTime(DateTime? when, {DateTime? now}) {
  if (when == null) return '—';
  final ref = now ?? DateTime.now();
  final delta = ref.difference(when);
  if (delta.isNegative) return 'just now';
  if (delta.inSeconds < 5) return 'just now';
  if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

/// Pure helper — the next mode to send to `toggleDroneMaintenance` when the
/// admin taps the named action. `null` means the action is disallowed
/// (drone is flying, or already in a state where the button shouldn't toggle).
@visibleForTesting
String? nextMaintenanceMode(String current) {
  switch (current) {
    case 'maintenance':
      return 'idle';
    case 'idle':
    case 'offline':
      return 'maintenance';
    default:
      return null; // flying / retired / unknown
  }
}

@visibleForTesting
String? nextOfflineMode(String current) {
  switch (current) {
    case 'offline':
      return 'idle';
    case 'idle':
    case 'maintenance':
      return 'offline';
    default:
      return null;
  }
}

class AdminDroneDetailPage extends ConsumerWidget {
  const AdminDroneDetailPage({super.key, required this.droneId});

  final String droneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(droneDocStreamProvider(droneId));

    return Scaffold(
      appBar: AppBar(title: Text(droneId.toUpperCase())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load drone: $e')),
        data: (drone) {
          if (drone == null) {
            return const Center(child: Text('Drone not found.'));
          }
          return _DroneDetailBody(drone: drone);
        },
      ),
    );
  }
}

class _DroneDetailBody extends ConsumerWidget {
  const _DroneDetailBody({required this.drone});
  final Drone drone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flying = drone.status == 'flying';
    final statusColor = droneStatusColor(drone.status, theme.colorScheme);
    final maintNext = nextMaintenanceMode(drone.status);
    final offlineNext = nextOfflineMode(drone.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(drone.name, style: theme.textTheme.headlineSmall),
            const Spacer(),
            Chip(
              key: const Key('drone-detail-status'),
              label: Text(
                droneStatusLabel(drone.status),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: statusColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MetricRow(
          label: 'Battery',
          child: Row(
            children: [
              Expanded(
                child: BatteryBar(percent: drone.batteryPct.toDouble()),
              ),
              const SizedBox(width: 12),
              Text(
                '${drone.batteryPct}%',
                key: const Key('drone-detail-battery'),
              ),
            ],
          ),
        ),
        _MetricRow(
          label: 'Payload',
          value: 'max ${drone.maxPayloadKg.toStringAsFixed(1)} kg',
        ),
        _MetricRow(
          label: 'Base',
          value:
              '${drone.baseLat.toStringAsFixed(4)}, ${drone.baseLng.toStringAsFixed(4)}',
        ),
        _MetricRow(
          label: 'Last seen',
          value: relativeTime(drone.lastSeenAt),
          valueKey: const Key('drone-detail-last-seen'),
        ),
        const SizedBox(height: 24),
        Text('Actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (flying)
          Text(
            'Wait until flight ends.',
            key: const Key('drone-detail-flying-hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('drone-detail-edit'),
                onPressed: flying
                    ? null
                    : () => showEditDroneDialog(context, drone),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: drone.status == 'retired'
                  ? OutlinedButton.icon(
                      key: const Key('drone-detail-restore'),
                      onPressed: () => _confirmAndApply(
                        context,
                        drone: drone,
                        nextMode: 'idle',
                        actionLabel: 'Restore',
                      ),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
                    )
                  : OutlinedButton.icon(
                      key: const Key('drone-detail-retire'),
                      onPressed: flying
                          ? null
                          : () => _retireDrone(context, drone),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Retire',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('drone-detail-take-offline'),
                onPressed: offlineNext == null
                    ? null
                    : () => _confirmAndApply(
                          context,
                          drone: drone,
                          nextMode: offlineNext,
                          actionLabel: offlineNext == 'offline'
                              ? 'Take offline'
                              : 'Bring online',
                        ),
                icon: const Icon(Icons.power_settings_new),
                label: Text(
                  drone.status == 'offline' ? 'Bring online' : 'Take offline',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('drone-detail-maintenance'),
                onPressed: maintNext == null
                    ? null
                    : () => _confirmAndApply(
                          context,
                          drone: drone,
                          nextMode: maintNext,
                          actionLabel: maintNext == 'maintenance'
                              ? 'Maintenance'
                              : 'End maintenance',
                        ),
                icon: const Icon(Icons.build_outlined),
                label: Text(
                  drone.status == 'maintenance'
                      ? 'End maintenance'
                      : 'Maintenance',
                ),
              ),
            ),
          ],
        ),
        if (drone.currentFlightId != null) ...[
          const SizedBox(height: 24),
          Text('Current flight', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _CurrentFlightPanel(flightId: drone.currentFlightId!),
        ],
        const SizedBox(height: 24),
        Text('Recent flights', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _RecentFlightsList(droneId: drone.id),
      ],
    );
  }
}

class _CurrentFlightPanel extends ConsumerWidget {
  const _CurrentFlightPanel({required this.flightId});
  final String flightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flightStreamProvider(flightId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        'Failed to load flight: $e',
        key: const Key('drone-detail-flight-error'),
      ),
      data: (flight) {
        if (flight == null) {
          return const Text(
            'Flight not found.',
            key: Key('drone-detail-flight-missing'),
          );
        }
        return Card(
          key: const Key('drone-detail-current-flight'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        flight.id,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    _StatusPill(status: flight.status),
                  ],
                ),
                const SizedBox(height: 8),
                _kv('To', '${flight.destination.latitude.toStringAsFixed(4)}, '
                    '${flight.destination.longitude.toStringAsFixed(4)}'),
                _kv('Takeoff', _fmtTs(flight.takeoffAt)),
                _kv('ETA', _fmtTs(flight.etaAt)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentFlightsList extends ConsumerWidget {
  const _RecentFlightsList({required this.droneId});
  final String droneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flightsByDroneStreamProvider(droneId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        'Failed to load history: $e',
        key: const Key('drone-detail-history-error'),
      ),
      data: (flights) {
        if (flights.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No flights yet.',
              key: Key('drone-detail-history-empty'),
            ),
          );
        }
        return Column(
          key: const Key('drone-detail-history'),
          children: [
            for (final f in flights)
              ListTile(
                key: Key('drone-detail-history-${f.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(f.id),
                subtitle: Text(_fmtTs(f.takeoffAt)),
                trailing: _StatusPill(status: f.status),
              ),
          ],
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }
}

Widget _kv(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

String _fmtTs(DateTime when) {
  return DateFormat('MMM d, h:mm a').format(when.toLocal());
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    this.value,
    this.child,
    this.valueKey,
  });

  final String label;
  final String? value;
  final Widget? child;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: child ??
                Text(
                  value ?? '—',
                  key: valueKey,
                  style: theme.textTheme.bodyMedium,
                ),
          ),
        ],
      ),
    );
  }
}

Future<void> _retireDrone(BuildContext context, Drone drone) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Retire ${drone.name}?'),
      content: const Text(
        'The drone is soft-deleted: hidden from the fleet list and refused '
        'for new flights. You can restore it later from the Retired filter.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Retire'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
    await fns.httpsCallable('retireDrone').call<Map<String, dynamic>>(
      {'droneId': drone.id},
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${drone.name} retired.')),
    );
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}

Future<void> _confirmAndApply(
  BuildContext context, {
  required Drone drone,
  required String nextMode,
  required String actionLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$actionLabel — ${drone.name}?'),
      content: Text(
        'Drone will move from "${droneStatusLabel(drone.status)}" '
        'to "${droneStatusLabel(nextMode)}".',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
    await fns.httpsCallable('toggleDroneMaintenance').call<Map<String, dynamic>>(
      {'droneId': drone.id, 'mode': nextMode},
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${drone.name} is now ${droneStatusLabel(nextMode)}.')),
    );
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}
