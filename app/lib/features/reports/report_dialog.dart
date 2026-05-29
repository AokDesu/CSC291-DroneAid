// User-facing dialog for filing a Report. The State owns the
// TextEditingController so its dispose() runs as part of the dialog
// teardown (fa2f710 — see commit). Used by:
//   - confirm_page.dart "Something's wrong — report"
//   - history_page.dart detail sheet "Report a problem"

import 'package:flutter/material.dart';

/// Shows the report dialog and returns the trimmed non-empty message,
/// or null if the user cancelled.
Future<String?> showReportDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
}

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
