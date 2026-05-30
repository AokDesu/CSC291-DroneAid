// Design tokens — spacing, radii, durations.
// Spec: docs/09-page-flow-design.md §1.2.

import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pageAll = EdgeInsets.all(md);
}

class AppRadii {
  AppRadii._();
  static const double card = 14;
  static const double tile = 10;
  static const double button = 12;
  static const double chip = 999;
  static const double iconTile = 10;
  static const double appBarAction = 12;
}

class AppDurations {
  AppDurations._();
  static const Duration fade = Duration(milliseconds: 200);
  static const Duration tick = Duration(seconds: 1);
}
