// Colored-initials avatar circle. Color is hashed from the name so the same
// user always renders the same hue across the app (matches admin requests
// screenshot — NC pink, MS blue, etc.).

import 'package:flutter/material.dart';

class UserAvatarInitials extends StatelessWidget {
  const UserAvatarInitials({
    super.key,
    required this.name,
    this.radius = 14,
    this.fontSize,
  });

  final String name;
  final double radius;
  final double? fontSize;

  static const _palette = <List<Color>>[
    [Color(0xFFFCDADE), Color(0xFFA93E5C)], // pink
    [Color(0xFFD6E8FB), Color(0xFF1F4F87)], // blue
    [Color(0xFFE1DDF1), Color(0xFF4A3C8A)], // lilac
    [Color(0xFFFCE7CF), Color(0xFF8A4A12)], // peach
    [Color(0xFFDDF2EE), Color(0xFF1F6F6C)], // mint
    [Color(0xFFFFF1C7), Color(0xFF7A5A00)], // yellow
    [Color(0xFFFBD7CE), Color(0xFFA93E22)], // salmon
    [Color(0xFFE0EAD8), Color(0xFF456B2F)], // sage
  ];

  static String initialsFor(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static List<Color> _huePair(String seed) {
    var h = 0;
    for (final code in seed.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsFor(name);
    final pair = _huePair(name.isEmpty ? '?' : name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: pair[0],
      child: Text(
        initials,
        style: TextStyle(
          color: pair[1],
          fontWeight: FontWeight.w700,
          fontSize: fontSize ?? radius * 0.85,
        ),
      ),
    );
  }
}
