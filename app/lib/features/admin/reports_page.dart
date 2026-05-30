// Admin-side Reports queue. Lists every open Report across all Requests
// so the admin has a real "what needs my attention now" view instead of
// having to dig through Request detail pages.
//
// Tapping a row navigates to /admin/requests/{reqId}, where the Reports
// section + Resolve/Dismiss bottom sheet live (see
// admin_request_detail_page.dart). The action UI lives on the Request
// detail page because resolving requires Request context (Confirm vs
// Fail outcome).
//
// Spec: docs/adr/0004-reports-as-first-class-dispute-entity.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../core/widgets/page_header.dart';
import '../reports/report.dart';
import '../reports/reports_providers.dart';
import 'requests/admin_requests_provider.dart';
import 'requests_page.dart' show relativeAge;

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOpenReportsProvider);
    final names = ref.watch(userNamesProvider).valueOrNull ??
        const <String, String>{};

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load reports: $e')),
        data: (reports) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                eyebrow: 'P-A-REPORTS · OPEN',
                title: 'Reports',
                subtitle: reports.isEmpty
                    ? 'Nothing pending.'
                    : '${reports.length} open · awaiting decision.',
              ),
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No open reports right now.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final r in reports)
                  _ReportRow(report: r, userNames: names),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.userNames});

  final Report report;
  final Map<String, String> userNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = userNames[report.uid] ?? report.uid;
    final age = relativeAge(report.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm,
      ),
      child: Card(
        child: InkWell(
          key: Key('report-row-${report.id}'),
          onTap: () => context.go('/admin/requests/${report.requestId}'),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: const Text('open'),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                report.message,
                style: theme.textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'on #${report.requestId}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(age, style: theme.textTheme.bodySmall),
                  if (report.requestStatusAtFiling != null)
                    Text(
                      'at: ${report.requestStatusAtFiling}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
