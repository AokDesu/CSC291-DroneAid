// P-A-01 Admin Requests list.
// Spec: docs/09-page-flow-design.md §6 P-A-01.
// Visual: docs/prototype-screens/admin/P-A-01_admin_requests.png.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/category_icon_tile.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/request_id_text.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/user_avatar_initials.dart';
import 'requests/admin_request.dart';
import 'requests/admin_requests_provider.dart';

String relativeAge(DateTime? when, {DateTime? now}) {
  if (when == null) return '—';
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}';
}

@visibleForTesting
String formatAdminItemSummary(List<AdminRequestItem> items) {
  if (items.isEmpty) return '(no items)';
  return items.map((it) => '${it.catalogId} ×${it.qty}').join(' · ');
}

class AdminRequestsPage extends ConsumerStatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  ConsumerState<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends ConsumerState<AdminRequestsPage> {
  AdminRequestFilter _filter = AdminRequestFilter.all;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminAllRequestsProvider);
    final names = ref.watch(userNamesProvider).valueOrNull ??
        const <String, String>{};
    final pendingCount = (async.valueOrNull ?? const <AdminRequest>[])
        .where((r) => r.status == 'pending')
        .length;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load requests: $e',
          onRetry: () => ref.invalidate(adminAllRequestsProvider),
        ),
        data: (all) {
          final filtered = filterRequests(
            all,
            filter: _filter,
            search: _search.text,
            userNames: names,
          );
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                eyebrow: 'P-A-01 · TRIAGE',
                title: 'Requests',
                subtitle:
                    '$pendingCount pending · live feed from users.',
              ),
              _FilterChipRow(
                value: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md,
                ),
                child: TextField(
                  key: const Key('admin-requests-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Search by user name or request id',
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No requests match this filter.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final r in filtered)
                  _AdminRequestRow(
                    request: r,
                    userNames: names,
                  ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.value, required this.onChanged});
  final AdminRequestFilter value;
  final ValueChanged<AdminRequestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final f in AdminRequestFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('chip-${f.name}'),
                label: Text(f.label),
                selected: value == f,
                onSelected: (_) => onChanged(f),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                selectedColor:
                    t.colorScheme.primary.withValues(alpha: 0.18),
                side: BorderSide(color: t.dividerColor),
                labelStyle: TextStyle(
                  color: value == f
                      ? t.colorScheme.primary
                      : t.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminRequestRow extends StatelessWidget {
  const _AdminRequestRow({required this.request, required this.userNames});

  final AdminRequest request;
  final Map<String, String> userNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = userNames[request.userId] ?? request.userId;
    final label = request.deliveryLabel;
    final summary = formatAdminItemSummary(request.items);
    final age = relativeAge(request.createdAt);
    final mono = context.appText.mono;
    final isUrgent = request.priority == 'urgent';
    final firstCatalog = request.items.isEmpty
        ? 'misc'
        : request.items.first.catalogId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2,
      ),
      child: Card(
        child: InkWell(
          key: Key('admin-row-${request.id}'),
          onTap: () => context.go('/admin/requests/${request.id}'),
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
                    Text(age, style: mono),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    UserAvatarInitials(name: name, radius: 12),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                Row(
                  children: [
                    CategoryIconTile(catalogId: firstCatalog, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        summary,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${request.totalWeightKg.toStringAsFixed(1)} kg',
                      style: mono,
                    ),
                    if (label != null && label.isNotEmpty)
                      Text(label, style: mono),
                    if (request.currentFlightId != null)
                      Text(
                        'Flight ${request.currentFlightId}',
                        style: mono,
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
