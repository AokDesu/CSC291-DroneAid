// P-U-06 Confirm — delivery confirm flow.
// Spec: docs/09-page-flow-design.md §5 P-U-06. Flow F-13.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_errors.dart';

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
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
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
      appBar: AppBar(title: const Text('Confirm receipt')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load request: ${describeFunctionsError(e)}')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Request not found.'));
          }
          final rawItems = (data['items'] as List?) ?? const [];
          final deliveredAt = data['deliveredAt'] ?? data['createdAt'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Did you receive your supplies?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Items: ${_formatItems(rawItems)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivered at ${_formatTime(deliveredAt)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _loading ? null : _confirm,
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
                  onPressed: _loading ? null : _reportProblem,
                  child: const Text("Something's wrong — report"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dialog whose State owns the TextEditingController, so its dispose()
/// runs as part of the dialog teardown — never inline after `await`,
/// which is what was crashing the app with the _dependents.isEmpty
/// assertion during dialog dismissal.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report a problem'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Describe the issue…',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
