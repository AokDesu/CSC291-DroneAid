// P-U-07 History — terminal-state requests for the signed-in user.
// Spec: docs/09-page-flow-design.md §5 P-U-07.
//
// Reuses myRequestsProvider + catalogNamesProvider + bucketFor from P-U-04
// (request/app_request.dart, request/queue_provider.dart) so both pages
// share a single Firestore stream subscription and one source of truth for
// status bucketing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/status_chip.dart';
import 'request/app_request.dart';
import 'request/queue_provider.dart';

/// Pure helper — buckets terminal-state requests by their createdAt date,
/// newest day first. Days themselves preserve the input order (which is
/// already createdAt-desc per `myRequestsProvider`), so the per-day rows
/// stay newest-first.
@visibleForTesting
List<MapEntry<DateTime, List<AppRequest>>> groupByDay(List<AppRequest> items) {
  final groups = <DateTime, List<AppRequest>>{};
  for (final r in items) {
    final ts = r.createdAt;
    if (ts == null) continue;
    final day = DateTime(ts.year, ts.month, ts.day);
    (groups[day] ??= <AppRequest>[]).add(r);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return entries;
}

/// Pure helper — "Mon, Jun 4" style label. Locale-naive on purpose to keep
/// tests deterministic; intl can layer on later without breaking callers.
@visibleForTesting
String formatDayHeader(DateTime day) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    final namesAsync = ref.watch(catalogNamesProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (all) {
          final history = all
              .where((r) => r.bucket == QueueBucket.hidden)
              .toList(growable: false);
          final names = namesAsync.valueOrNull ?? const <String, String>{};

          if (history.isEmpty) {
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

          final grouped = groupByDay(history);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRequestsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final entry = grouped[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Text(
                        formatDayHeader(entry.key),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final r in entry.value)
                      _HistoryRow(request: r, catalogNames: names),
                  ],
                );
              },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No past deliveries yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Completed, cancelled, and rejected requests show up here.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.request, required this.catalogNames});

  final AppRequest request;
  final Map<String, String> catalogNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = formatItemSummary(request.items, catalogNames);
    final time = relativeTime(request.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        key: Key('history-row-${request.id}'),
        onTap: () => _showDetailSheet(context, request, summary),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showDetailSheet(
  BuildContext context,
  AppRequest request,
  String summary,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${request.id}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Items', value: summary),
              _DetailRow(
                label: 'Total weight',
                value: '${request.totalWeightKg.toStringAsFixed(1)} kg',
              ),
              _DetailRow(
                label: 'Submitted',
                value: request.createdAt?.toString() ?? '—',
              ),
              if (request.currentFlightId != null)
                _DetailRow(
                  label: 'Last flight',
                  value: request.currentFlightId!,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
