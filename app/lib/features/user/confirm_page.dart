// P-U-06 Confirm — delivery confirm flow.
// Spec: docs/09-page-flow-design.md §5 P-U-06. Flow F-13.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_errors.dart';
import '../reports/report_dialog.dart';
import 'history_page.dart' show reportFilableStatuses;

const _region = 'asia-southeast1';

final _reqProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, reqId) => FirebaseFirestore.instance
      .doc('requests/$reqId')
      .snapshots()
      .map((s) => s.data()),
);

class ConfirmPage extends ConsumerStatefulWidget {
  const ConfirmPage({super.key, required this.reqId});
  final String reqId;

  @override
  ConsumerState<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends ConsumerState<ConfirmPage> {
  bool _loading = false;

  String _formatItems(List<dynamic> raw) {
    if (raw.isEmpty) return '(no items)';
    return raw
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final id = (m['catalogId'] as String?) ?? '?';
          final qty = (m['qty'] as num?)?.toInt() ?? 0;
          return '$id ×$qty';
        })
        .join(', ');
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    final dt = (ts as Timestamp).toDate().toLocal();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('confirmDelivery')
          .call({'reqId': widget.reqId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — supplies received.')),
      );
      context.go('/user/queue');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: ${describeFunctionsError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportProblem() async {
    final message = await showReportDialog(context);
    if (message == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('reportDeliveryIssue')
          .call<Map<String, dynamic>>({
        'reqId': widget.reqId,
        'message': message,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Report sent. Coordinator notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send report: ${describeFunctionsError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reqProvider(widget.reqId));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/user/queue');
            }
          },
        ),
        title: const Text('Confirm receipt'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load request: ${describeFunctionsError(e)}')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Request not found.'));
          }
          final rawItems = (data['items'] as List?) ?? const [];
          final deliveredAt = data['deliveredAt'] ?? data['createdAt'];
          final status = (data['status'] as String?) ?? '';
          // Confirm callable only accepts 'delivered' (normal path) or
          // 'in_flight' (Tracking-page early-confirm — must be at destination).
          final canConfirm = status == 'delivered' || status == 'in_flight';
          // Report callable rejects mid-flight requests — only filable once
          // the delivery has landed (see reportDeliveryIssue.ts +
          // docs/adr/0004-reports-as-first-class-dispute-entity.md).
          final canReport = reportFilableStatuses.contains(status);
          final blockedReason = canConfirm
              ? null
              : status == 'confirmed'
                  ? 'This delivery is already confirmed.'
                  : status.isEmpty
                      ? 'Request status unavailable.'
                      : 'This request is "$status" — not ready to confirm.';
          final t = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: t.colorScheme.primary,
                        ),
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF2D8C7F),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Did you receive your supplies?',
                  style: t.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _formatItems(rawItems),
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivered at ${_formatTime(deliveredAt)}',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall,
                ),
                const Spacer(),
                if (blockedReason != null) ...[
                  Text(
                    blockedReason,
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: (_loading || !canConfirm) ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Yes, confirm'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: (_loading || !canReport) ? null : _reportProblem,
                  child: Text(
                    canReport
                        ? "Something's wrong — report"
                        : 'Report unavailable yet',
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

