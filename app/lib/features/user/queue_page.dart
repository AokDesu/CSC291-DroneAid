// P-U-04 Queue — pending + active requests for the signed-in user.
// Spec: docs/09-page-flow-design.md §5 P-U-04.
// Visual: docs/prototype-screens/user/P-U-04_queue.png.
// Flow F-09 (cancel) wires through the `cancelRequest` callable.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/loading_placeholder.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/request_id_text.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/status_chip.dart';
import 'request/app_request.dart';
import 'request/queue_provider.dart';
import 'tracking/flight_provider.dart';
import 'tracking/interpolation.dart';

const _functionsRegion = 'asia-southeast1';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    final namesAsync = ref.watch(catalogNamesProvider);

    return Scaffold(
      body: async.when(
        loading: () => const LoadingPlaceholder(label: 'Loading your queue…'),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load: $e',
          onRetry: () => ref.invalidate(myRequestsProvider),
        ),
        data: (all) {
          final pending = all.where((r) => r.bucket == QueueBucket.pending).toList();
          final active = all.where((r) => r.bucket == QueueBucket.active).toList();
          final names = namesAsync.valueOrNull ?? const <String, String>{};

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRequestsProvider),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const PageHeader(
                  eyebrow: 'P-U-04 · LIVE UPDATES',
                  title: 'Your queue',
                  subtitle:
                      'Submitted requests update in real time as admins assign and drones fly.',
                ),
                if (pending.isEmpty && active.isEmpty)
                  const _EmptyState()
                else ...[
                  if (active.isNotEmpty) ...[
                    const SectionLabel('ACTIVE'),
                    for (final r in active)
                      _QueueRow(request: r, catalogNames: names),
                  ],
                  if (pending.isNotEmpty) ...[
                    const SectionLabel('PENDING'),
                    for (final r in pending)
                      _QueueRow(request: r, catalogNames: names),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/user/history'),
                    child: const Text('See past deliveries →'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            'No active requests',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Submit a request from the Request tab to see it here.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({required this.request, required this.catalogNames});

  final AppRequest request;
  final Map<String, String> catalogNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mono = context.appText.mono;
    final summary = formatItemSummary(request.items, catalogNames);
    final time = relativeTime(request.createdAt);
    final isInFlight = request.status == 'in_flight';
    final isPending = request.status == 'pending';
    final isDelivered = request.status == 'delivered';
    final isUrgent = (request.priority ?? 'normal') == 'urgent';

    void onTap() {
      if (isInFlight && request.currentFlightId != null) {
        context.go('/user/tracking/${request.currentFlightId}');
      } else if (isDelivered) {
        context.go('/user/confirm/${request.id}');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2,
      ),
      child: Card(
        child: InkWell(
          key: Key('queue-row-${request.id}'),
          onTap: (isInFlight || isDelivered) ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RequestIdText(request.id),
                    StatusChip(status: request.status, dense: true),
                    if (isUrgent) const UrgentTag(dense: true),
                    Text(time, style: mono),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.totalWeightKg.toStringAsFixed(1)} kg'
                  '${request.deliveryLabel != null ? '   ·   ${request.deliveryLabel}' : ''}',
                  style: mono,
                ),
                if (isInFlight) ...[
                  const SizedBox(height: AppSpacing.sm + 2),
                  _ActiveFlightMetrics(request: request),
                ],
                if (isPending || isInFlight || isDelivered) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _RowAction(
                      isPending: isPending,
                      isInFlight: isInFlight,
                      isDelivered: isDelivered,
                      onAction: onTap,
                      request: request,
                    ),
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

class _ActiveFlightMetrics extends ConsumerStatefulWidget {
  const _ActiveFlightMetrics({required this.request});
  final AppRequest request;

  @override
  ConsumerState<_ActiveFlightMetrics> createState() =>
      _ActiveFlightMetricsState();
}

class _ActiveFlightMetricsState extends ConsumerState<_ActiveFlightMetrics> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-render every 30 s so ETA + battery stay current without a per-second
    // animation controller (the queue card doesn't need sub-second cadence).
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final flightId = widget.request.currentFlightId;
    final flightAsync = flightId == null
        ? const AsyncValue<FlightDoc?>.data(null)
        : ref.watch(flightStreamProvider(flightId));

    final flight = flightAsync.valueOrNull;
    String etaValue = '—';
    String batteryValue = '—';
    String droneValue = flightId ?? '—';
    if (flight != null) {
      droneValue = flight.droneId.isNotEmpty ? flight.droneId : flightId!;
      final now = DateTime.now();
      etaValue = etaLabel(etaRemaining(flight.etaAt, now));
      final snap = flightSnapshot(
        origin: flight.origin,
        destination: flight.destination,
        takeoffAt: flight.takeoffAt,
        speedKmh: flight.speedKmh,
        weatherModifier: flight.weatherModifier,
        batteryAtTakeoff: flight.batteryAtTakeoff,
        now: now,
      );
      batteryValue = '${snap.battery.round()}%';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MetricTile(label: 'ETA', value: etaValue),
          MetricTile(label: 'BATTERY', value: batteryValue),
          MetricTile(label: 'DRONE', value: droneValue),
        ],
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.isPending,
    required this.isInFlight,
    required this.isDelivered,
    required this.onAction,
    required this.request,
  });

  final bool isPending;
  final bool isInFlight;
  final bool isDelivered;
  final VoidCallback onAction;
  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return TextButton(
        key: Key('cancel-${request.id}'),
        onPressed: () => _confirmCancel(context, request),
        child: const Text('Cancel'),
      );
    }
    if (isInFlight) {
      return OutlinedButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.place_outlined, size: 16),
        label: const Text('Track'),
      );
    }
    if (isDelivered) {
      return FilledButton(
        onPressed: onAction,
        child: const Text('Confirm'),
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> _confirmCancel(BuildContext context, AppRequest request) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this request?'),
      content: const Text(
        'It will move to your History as "cancelled" and the assigned drone (if any) is released.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cancel request'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
    await fns
        .httpsCallable('cancelRequest')
        .call<Map<String, dynamic>>({'reqId': request.id});
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Request cancelled.')));
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Cancel failed: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
  }
}
