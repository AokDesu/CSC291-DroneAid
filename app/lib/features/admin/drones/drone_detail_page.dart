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

import '../../../core/widgets/battery_bar.dart';
import '../drones_page.dart' show droneStatusColor, droneStatusLabel;
import 'drone.dart';
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
      return null; // flying / unknown
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

class _DroneDetailBody extends StatelessWidget {
  const _DroneDetailBody({required this.drone});
  final Drone drone;

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
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
      SnackBar(content: Text('${drone.name} → ${droneStatusLabel(nextMode)}')),
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
