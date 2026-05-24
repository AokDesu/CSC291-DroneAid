// P-A-01 Admin Requests list.
// Spec: docs/09-page-flow-design.md §6 P-A-01.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/status_chip.dart';
import 'requests/admin_request.dart';
import 'requests/admin_requests_provider.dart';

/// Pure helper — "Just now", "7 min ago", "Yesterday", "Mar 14". Mirrors
/// the user-side helper, kept local so this page stays decoupled from the
/// user-side queue PR until that lands.
@visibleForTesting
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

/// Pure helper — "food-kit ×2 · blanket ×1". Falls back to the raw
/// catalogId since the admin list does not need a catalog name lookup on
/// this row (kept lightweight).
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

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('admin-requests-search'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by user name or request id',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final f in AdminRequestFilter.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      key: Key('chip-${f.name}'),
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load requests: $e')),
              data: (all) {
                final filtered = filterRequests(
                  all,
                  filter: _filter,
                  search: _search.text,
                  userNames: names,
                );
                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No requests match this filter.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _AdminRequestRow(
                    request: filtered[i],
                    userNames: names,
                  ),
                );
              },
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

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: Key('admin-row-${request.id}'),
        onTap: () => context.go('/admin/requests/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                  StatusChip(status: request.status),
                ],
              ),
              if (label != null && label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 6),
              Text(summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('#${request.id}', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Text(
                    '${request.totalWeightKg.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(age, style: theme.textTheme.bodySmall),
                  if (request.currentFlightId != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Flight ${request.currentFlightId}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (request.priority == 'urgent') ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.priority_high,
                      size: 16,
                      color: theme.colorScheme.error,
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
