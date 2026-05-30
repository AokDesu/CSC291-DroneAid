// ThemeExtensions — locked palette + text styles matching prototype screenshots.
// Screenshots under docs/prototype-screens/ are canonical when spec text disagrees.

import 'package:flutter/material.dart';

/// Status pill palette (locked to prototype screenshot colors).
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.pendingBg,
    required this.pendingFg,
    required this.inFlightBg,
    required this.inFlightFg,
    required this.urgentBg,
    required this.urgentFg,
    required this.confirmedBg,
    required this.confirmedFg,
    required this.failedBg,
    required this.failedFg,
    required this.cancelledBg,
    required this.cancelledFg,
    required this.approvedBg,
    required this.approvedFg,
    required this.deliveredBg,
    required this.deliveredFg,
  });

  final Color pendingBg;
  final Color pendingFg;
  final Color inFlightBg;
  final Color inFlightFg;
  final Color urgentBg;
  final Color urgentFg;
  final Color confirmedBg;
  final Color confirmedFg;
  final Color failedBg;
  final Color failedFg;
  final Color cancelledBg;
  final Color cancelledFg;
  final Color approvedBg;
  final Color approvedFg;
  final Color deliveredBg;
  final Color deliveredFg;

  static const light = AppStatusColors(
    pendingBg: Color(0xFFFFF1D6),
    pendingFg: Color(0xFFA06A00),
    inFlightBg: Color(0xFFEEF1F4),
    inFlightFg: Color(0xFF3C4250),
    urgentBg: Color(0xFFE85B3D),
    urgentFg: Color(0xFFFFFFFF),
    confirmedBg: Color(0xFFDDF2EE),
    confirmedFg: Color(0xFF1F6F6C),
    failedBg: Color(0xFFFBD7CE),
    failedFg: Color(0xFFA93E22),
    cancelledBg: Color(0xFFE1E4E8),
    cancelledFg: Color(0xFF5B6470),
    approvedBg: Color(0xFFD6EEF0),
    approvedFg: Color(0xFF005F60),
    deliveredBg: Color(0xFFFFE6B8),
    deliveredFg: Color(0xFF7A4A00),
  );

  static const dark = AppStatusColors(
    pendingBg: Color(0xFF3F3318),
    pendingFg: Color(0xFFFFD68A),
    inFlightBg: Color(0xFF22272F),
    inFlightFg: Color(0xFFD3D8E0),
    urgentBg: Color(0xFFE85B3D),
    urgentFg: Color(0xFFFFFFFF),
    confirmedBg: Color(0xFF1B3A37),
    confirmedFg: Color(0xFF6BD3C8),
    failedBg: Color(0xFF3F1F17),
    failedFg: Color(0xFFFFB69D),
    cancelledBg: Color(0xFF2A2E33),
    cancelledFg: Color(0xFFB6BCC4),
    approvedBg: Color(0xFF1A3537),
    approvedFg: Color(0xFF6BC8CB),
    deliveredBg: Color(0xFF3A2A0E),
    deliveredFg: Color(0xFFFFCB78),
  );

  @override
  AppStatusColors copyWith({
    Color? pendingBg, Color? pendingFg,
    Color? inFlightBg, Color? inFlightFg,
    Color? urgentBg, Color? urgentFg,
    Color? confirmedBg, Color? confirmedFg,
    Color? failedBg, Color? failedFg,
    Color? cancelledBg, Color? cancelledFg,
    Color? approvedBg, Color? approvedFg,
    Color? deliveredBg, Color? deliveredFg,
  }) =>
      AppStatusColors(
        pendingBg: pendingBg ?? this.pendingBg,
        pendingFg: pendingFg ?? this.pendingFg,
        inFlightBg: inFlightBg ?? this.inFlightBg,
        inFlightFg: inFlightFg ?? this.inFlightFg,
        urgentBg: urgentBg ?? this.urgentBg,
        urgentFg: urgentFg ?? this.urgentFg,
        confirmedBg: confirmedBg ?? this.confirmedBg,
        confirmedFg: confirmedFg ?? this.confirmedFg,
        failedBg: failedBg ?? this.failedBg,
        failedFg: failedFg ?? this.failedFg,
        cancelledBg: cancelledBg ?? this.cancelledBg,
        cancelledFg: cancelledFg ?? this.cancelledFg,
        approvedBg: approvedBg ?? this.approvedBg,
        approvedFg: approvedFg ?? this.approvedFg,
        deliveredBg: deliveredBg ?? this.deliveredBg,
        deliveredFg: deliveredFg ?? this.deliveredFg,
      );

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      pendingBg: Color.lerp(pendingBg, other.pendingBg, t)!,
      pendingFg: Color.lerp(pendingFg, other.pendingFg, t)!,
      inFlightBg: Color.lerp(inFlightBg, other.inFlightBg, t)!,
      inFlightFg: Color.lerp(inFlightFg, other.inFlightFg, t)!,
      urgentBg: Color.lerp(urgentBg, other.urgentBg, t)!,
      urgentFg: Color.lerp(urgentFg, other.urgentFg, t)!,
      confirmedBg: Color.lerp(confirmedBg, other.confirmedBg, t)!,
      confirmedFg: Color.lerp(confirmedFg, other.confirmedFg, t)!,
      failedBg: Color.lerp(failedBg, other.failedBg, t)!,
      failedFg: Color.lerp(failedFg, other.failedFg, t)!,
      cancelledBg: Color.lerp(cancelledBg, other.cancelledBg, t)!,
      cancelledFg: Color.lerp(cancelledFg, other.cancelledFg, t)!,
      approvedBg: Color.lerp(approvedBg, other.approvedBg, t)!,
      approvedFg: Color.lerp(approvedFg, other.approvedFg, t)!,
      deliveredBg: Color.lerp(deliveredBg, other.deliveredBg, t)!,
      deliveredFg: Color.lerp(deliveredFg, other.deliveredFg, t)!,
    );
  }
}

/// Category-icon tinted square palette (catalog items, fleet states, ...).
@immutable
class AppCategoryTints extends ThemeExtension<AppCategoryTints> {
  const AppCategoryTints({
    required this.food,
    required this.water,
    required this.medical,
    required this.babyFormula,
    required this.blanket,
    required this.flashlight,
    required this.fallback,
    required this.foreground,
  });

  final Color food;
  final Color water;
  final Color medical;
  final Color babyFormula;
  final Color blanket;
  final Color flashlight;
  final Color fallback;
  final Color foreground;

  static const light = AppCategoryTints(
    food: Color(0xFFFCE7CF),
    water: Color(0xFFD6E8FB),
    medical: Color(0xFFFCDADE),
    babyFormula: Color(0xFFF5D3DF),
    blanket: Color(0xFFE1DDF1),
    flashlight: Color(0xFFFFF1C7),
    fallback: Color(0xFFEEF1F4),
    foreground: Color(0xFF1F2937),
  );

  static const dark = AppCategoryTints(
    food: Color(0xFF3F3018),
    water: Color(0xFF1A2A3A),
    medical: Color(0xFF3A1B22),
    babyFormula: Color(0xFF361A29),
    blanket: Color(0xFF22203A),
    flashlight: Color(0xFF3A3110),
    fallback: Color(0xFF22272F),
    foreground: Color(0xFFE6EAF0),
  );

  Color tintFor(String catalogId) {
    final k = catalogId.toLowerCase();
    if (k.contains('food')) return food;
    if (k.contains('water')) return water;
    if (k.contains('medical') || k.contains('med')) return medical;
    if (k.contains('baby') || k.contains('formula')) return babyFormula;
    if (k.contains('blanket')) return blanket;
    if (k.contains('flash') || k.contains('light')) return flashlight;
    return fallback;
  }

  @override
  AppCategoryTints copyWith({
    Color? food, Color? water, Color? medical,
    Color? babyFormula, Color? blanket, Color? flashlight,
    Color? fallback, Color? foreground,
  }) =>
      AppCategoryTints(
        food: food ?? this.food,
        water: water ?? this.water,
        medical: medical ?? this.medical,
        babyFormula: babyFormula ?? this.babyFormula,
        blanket: blanket ?? this.blanket,
        flashlight: flashlight ?? this.flashlight,
        fallback: fallback ?? this.fallback,
        foreground: foreground ?? this.foreground,
      );

  @override
  AppCategoryTints lerp(ThemeExtension<AppCategoryTints>? other, double t) {
    if (other is! AppCategoryTints) return this;
    return AppCategoryTints(
      food: Color.lerp(food, other.food, t)!,
      water: Color.lerp(water, other.water, t)!,
      medical: Color.lerp(medical, other.medical, t)!,
      babyFormula: Color.lerp(babyFormula, other.babyFormula, t)!,
      blanket: Color.lerp(blanket, other.blanket, t)!,
      flashlight: Color.lerp(flashlight, other.flashlight, t)!,
      fallback: Color.lerp(fallback, other.fallback, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
    );
  }
}

/// Extra typography roles not covered by Material's TextTheme.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.eyebrow,
    required this.sectionLabel,
    required this.mono,
    required this.monoStrong,
    required this.requestId,
    required this.metricLabel,
    required this.metricValue,
  });

  final TextStyle eyebrow;
  final TextStyle sectionLabel;
  final TextStyle mono;
  final TextStyle monoStrong;
  final TextStyle requestId;
  final TextStyle metricLabel;
  final TextStyle metricValue;

  static const _monoFamily = 'monospace';

  static AppTextStyles light(ColorScheme s) {
    const muted = Color(0xFF6B7280);
    return AppTextStyles(
      eyebrow: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: muted,
        fontFamily: _monoFamily,
      ),
      sectionLabel: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: muted,
      ),
      mono: const TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        color: muted,
        height: 1.3,
      ),
      monoStrong: const TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
        height: 1.3,
      ),
      requestId: TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        color: s.primary,
        fontWeight: FontWeight.w500,
      ),
      metricLabel: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: muted,
      ),
      metricValue: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  static AppTextStyles dark(ColorScheme s) {
    const muted = Color(0xFFA0A8B4);
    return AppTextStyles(
      eyebrow: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: muted,
        fontFamily: _monoFamily,
      ),
      sectionLabel: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: muted,
      ),
      mono: const TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        color: muted,
        height: 1.3,
      ),
      monoStrong: const TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE6EAF0),
        height: 1.3,
      ),
      requestId: TextStyle(
        fontSize: 13,
        fontFamily: _monoFamily,
        color: s.primary,
        fontWeight: FontWeight.w500,
      ),
      metricLabel: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: muted,
      ),
      metricValue: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFFE6EAF0),
      ),
    );
  }

  @override
  AppTextStyles copyWith({
    TextStyle? eyebrow,
    TextStyle? sectionLabel,
    TextStyle? mono,
    TextStyle? monoStrong,
    TextStyle? requestId,
    TextStyle? metricLabel,
    TextStyle? metricValue,
  }) =>
      AppTextStyles(
        eyebrow: eyebrow ?? this.eyebrow,
        sectionLabel: sectionLabel ?? this.sectionLabel,
        mono: mono ?? this.mono,
        monoStrong: monoStrong ?? this.monoStrong,
        requestId: requestId ?? this.requestId,
        metricLabel: metricLabel ?? this.metricLabel,
        metricValue: metricValue ?? this.metricValue,
      );

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
      monoStrong: TextStyle.lerp(monoStrong, other.monoStrong, t)!,
      requestId: TextStyle.lerp(requestId, other.requestId, t)!,
      metricLabel: TextStyle.lerp(metricLabel, other.metricLabel, t)!,
      metricValue: TextStyle.lerp(metricValue, other.metricValue, t)!,
    );
  }
}

/// Convenience accessors so callers can read `context.statusColors.urgentBg`
/// without typing `Theme.of(context).extension<AppStatusColors>()!` each time.
extension AppThemeX on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light;
  AppCategoryTints get categoryTints =>
      Theme.of(this).extension<AppCategoryTints>() ?? AppCategoryTints.light;
  AppTextStyles get appText {
    final t = Theme.of(this);
    return t.extension<AppTextStyles>() ??
        (t.brightness == Brightness.dark
            ? AppTextStyles.dark(t.colorScheme)
            : AppTextStyles.light(t.colorScheme));
  }
}
