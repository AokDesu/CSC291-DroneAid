// P-U-07 History — terminal-state requests for the signed-in user.
// Spec: docs/09-page-flow-design.md §5 P-U-07.
//
// Reuses myRequestsProvider + catalogNamesProvider + bucketFor from P-U-04
// (request/app_request.dart, request/queue_provider.dart) so both pages
// share a single Firestore stream subscription and one source of truth for
// status bucketing.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_errors.dart';
import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/loading_placeholder.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/request_id_text.dart';
import '../../core/widgets/status_chip.dart';
import '../reports/report.dart';
import '../reports/report_dialog.dart';
import '../reports/reports_providers.dart';
import 'request/app_request.dart';
import 'request/queue_provider.dart';

const _functionsRegion = 'asia-southeast1';

/// Request statuses where a Report may be filed (mirrors backend gate
/// in functions/src/callable/reportDeliveryIssue.ts).
const reportFilableStatuses = {'delivered', 'confirmed', 'failed'};

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
        loading: () => const LoadingPlaceholder(label: 'Loading history…'),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load: $e',
          onRetry: () => ref.invalidate(myRequestsProvider),
        ),
        data: (all) {
          final history = all
              .where((r) => r.bucket == QueueBucket.hidden)
              .toList(growable: false);
          final names = namesAsync.valueOrNull ?? const <String, String>{};

          final grouped = groupByDay(history);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRequestsProvider),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: grouped.length + 1 + (history.isEmpty ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return const PageHeader(
                    eyebrow: 'P-U-07 · HISTORY',
                    title: 'History',
                    subtitle: 'Past deliveries and resolved reports.',
                  );
                }
                if (history.isEmpty && i == 1) {
                  return const _EmptyState();
                }
                final entry = grouped[i - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        formatDayHeader(entry.key).toUpperCase(),
                        style: context.appText.sectionLabel,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm,
      ),
      child: Card(
        child: InkWell(
          key: Key('history-row-${request.id}'),
          onTap: () => _showDetailSheet(context, request, summary),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RequestIdText(request.id),
                    const SizedBox(width: 6),
                    StatusChip(status: request.status, dense: true),
                    const Spacer(),
                    Text(time, style: context.appText.mono),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  summary,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.totalWeightKg.toStringAsFixed(1)} kg'
                  '${request.currentFlightId != null ? '   ·   Flight ${request.currentFlightId}' : ''}',
                  style: context.appText.mono,
                ),
              ],
            ),
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
    builder: (ctx) => _DetailSheet(request: request, summary: summary),
  );
}

class _DetailSheet extends ConsumerStatefulWidget {
  const _DetailSheet({required this.request, required this.summary});
  final AppRequest request;
  final String summary;

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  bool _filing = false;

  Future<void> _fileReport() async {
    final message = await showReportDialog(context);
    if (message == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _filing = true);
    try {
      await FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable('reportDeliveryIssue')
          .call<Map<String, dynamic>>({
        'reqId': widget.request.id,
        'message': message,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Report sent. Coordinator notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not send report: ${describeFunctionsError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _filing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final reportsAsync = ref.watch(requestReportsProvider(request.id));
    final hasOpenReport = reportsAsync.maybeWhen(
      data: (rs) => rs.any((r) => r.status == ReportStatus.open),
      orElse: () => false,
    );
    final canReport = reportFilableStatuses.contains(request.status) &&
        !hasOpenReport;

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
            _DetailRow(label: 'Items', value: widget.summary),
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
            reportsAsync.maybeWhen(
              data: (reports) => reports.isEmpty
                  ? const SizedBox.shrink()
                  : _UserReportsList(reports: reports),
              orElse: () => const SizedBox.shrink(),
            ),
            if (canReport) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('history-report-button'),
                onPressed: _filing ? null : _fileReport,
                icon: const Icon(Icons.report_outlined),
                label: const Text('Report a problem'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserReportsList extends StatelessWidget {
  const _UserReportsList({required this.reports});
  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reports',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final r in reports)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _UserReportTile(report: r),
            ),
        ],
      ),
    );
  }
}

class _UserReportTile extends StatelessWidget {
  const _UserReportTile({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (report.status) {
      ReportStatus.open => theme.colorScheme.errorContainer,
      ReportStatus.resolved => theme.colorScheme.primaryContainer,
      ReportStatus.dismissed => theme.colorScheme.surfaceContainerHighest,
    };
    final onColor = switch (report.status) {
      ReportStatus.open => theme.colorScheme.onErrorContainer,
      ReportStatus.resolved => theme.colorScheme.onPrimaryContainer,
      ReportStatus.dismissed => theme.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                report.status.wire,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: onColor,
                ),
              ),
              const Spacer(),
              if (report.resolution != null)
                Text(
                  report.resolution!.label,
                  style: TextStyle(fontSize: 11, color: onColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            report.message,
            style: TextStyle(fontSize: 13, color: onColor),
          ),
          if (report.resolutionNote != null) ...[
            const SizedBox(height: 4),
            Text(
              'Admin: ${report.resolutionNote}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: onColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
