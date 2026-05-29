// P-U-04 Queue — pending + active requests for the signed-in user.
// Spec: docs/09-page-flow-design.md §5 P-U-04.
// Flow F-09 (cancel) wires through the `cancelRequest` callable.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/status_chip.dart';
import 'request/app_request.dart';
import 'request/queue_provider.dart';

const _functionsRegion = 'asia-southeast1';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    final namesAsync = ref.watch(catalogNamesProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (all) {
          final pending = all.where((r) => r.bucket == QueueBucket.pending).toList();
          final active = all.where((r) => r.bucket == QueueBucket.active).toList();
          final names = namesAsync.valueOrNull ?? const <String, String>{};

          if (pending.isEmpty && active.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(myRequestsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 96),
                  _EmptyState(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRequestsProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(label: 'Active', count: active.length),
                  for (final r in active)
                    _QueueRow(request: r, catalogNames: names),
                ],
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(label: 'Pending', count: pending.length),
                  for (final r in pending)
                    _QueueRow(request: r, catalogNames: names),
                ],
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/user/history'),
                    child: const Text('See past deliveries →'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text('($count)', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No active requests',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Submit a request from the Home tab to see it here.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final summary = formatItemSummary(request.items, catalogNames);
    final time = relativeTime(request.createdAt);
    final isInFlight = request.status == 'in_flight';
    final isPending = request.status == 'pending';
    final isDelivered = request.status == 'delivered';

    void onTap() {
      if (isInFlight && request.currentFlightId != null) {
        context.go('/user/tracking/${request.currentFlightId}');
      } else if (isDelivered) {
        context.go('/user/confirm/${request.id}');
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        key: Key('queue-row-${request.id}'),
        onTap: (isInFlight || isDelivered) ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${request.id}',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${request.totalWeightKg.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(time, style: theme.textTheme.bodySmall),
                  if (request.currentFlightId != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Flight ${request.currentFlightId}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  if (isPending)
                    TextButton(
                      key: Key('cancel-${request.id}'),
                      onPressed: () => _confirmCancel(context, request),
                      child: const Text('Cancel'),
                    ),
                  if (isInFlight)
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Track'),
                    ),
                  if (isDelivered)
                    TextButton(
                      onPressed: onTap,
                      child: const Text('Confirm'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
