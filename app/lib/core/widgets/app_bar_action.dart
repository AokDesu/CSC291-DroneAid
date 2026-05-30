// Soft-gray rounded-square wrapper for AppBar trailing actions
// (theme toggle, notification bell, profile avatar, weather chip).
// Matches the screenshot's pill-of-icons row.

import 'package:flutter/material.dart';

import '../tokens.dart';

class AppBarAction extends StatelessWidget {
  const AppBarAction({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.padding = const EdgeInsets.all(6),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF1F242B)
        : const Color(0xFFF2F4F8);
    final shape = BorderRadius.circular(AppRadii.appBarAction);

    final inner = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape,
      ),
      padding: padding,
      child: child,
    );

    Widget btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: inner,
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
