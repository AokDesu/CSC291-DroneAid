// Monospace `#req-xxxx` request ID. Matches the prototype's pill-list rows.

import 'package:flutter/material.dart';

import '../theme_extensions.dart';

class RequestIdText extends StatelessWidget {
  const RequestIdText(this.id, {super.key, this.style});

  /// Raw Firestore doc id (e.g. `req-77ab`) — leading `#` is added.
  final String id;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = context.appText.requestId;
    final display = id.startsWith('#') ? id : '#$id';
    return Text(display, style: style == null ? base : base.merge(style));
  }
}
