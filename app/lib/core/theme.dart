// Material 3 theme generated from a single seed color + locked extension palette.
// Spec: docs/09-page-flow-design.md §1.2; screenshots under docs/prototype-screens/
// are canonical when spec text disagrees.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_extensions.dart';
import 'tokens.dart';

const Color _seed = Color(0xFF006A6A); // teal seed

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
  return _baseTheme(scheme, brightness: Brightness.light);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
  return _baseTheme(scheme, brightness: Brightness.dark);
}

ThemeData _baseTheme(ColorScheme scheme, {required Brightness brightness}) {
  final isLight = brightness == Brightness.light;
  final surface = isLight ? const Color(0xFFFFFFFF) : scheme.surface;
  final scaffoldBg = isLight ? const Color(0xFFF7F8FA) : scheme.surface;
  final onSurface = isLight ? const Color(0xFF1F2937) : scheme.onSurface;
  final borderColor =
      isLight ? const Color(0xFFE6E9EF) : const Color(0xFF2A2F36);

  final baseText = isLight
      ? Typography.blackMountainView
      : Typography.whiteMountainView;
  final textTheme = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(fontWeight: FontWeight.w800),
    displayMedium: baseText.displayMedium?.copyWith(fontWeight: FontWeight.w800),
    displaySmall: baseText.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.15,
      color: onSurface,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.15,
      color: onSurface,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.18,
      color: onSurface,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: onSurface,
    ),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: baseText.bodyLarge?.copyWith(color: onSurface),
    bodyMedium: baseText.bodyMedium?.copyWith(
      color: isLight ? const Color(0xFF4B5563) : const Color(0xFFB7BFCA),
    ),
    labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBg,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      isLight ? AppStatusColors.light : AppStatusColors.dark,
      isLight ? AppCategoryTints.light : AppCategoryTints.dark,
      isLight ? AppTextStyles.light(scheme) : AppTextStyles.dark(scheme),
    ],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      systemOverlayStyle: isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: borderColor,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight
          ? const Color(0xFFF2F4F8)
          : const Color(0xFF1B1F25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: borderColor),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isLight ? const Color(0xFFF2F4F8) : const Color(0xFF1B1F25),
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: onSurface.withValues(alpha: 0.55));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final base = textTheme.labelMedium ?? const TextStyle(fontSize: 12);
        if (states.contains(WidgetState.selected)) {
          return base.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          );
        }
        return base.copyWith(
          color: onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        );
      }),
      height: 68,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: onSurface.withValues(alpha: 0.55),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 2.5),
        insets: const EdgeInsets.symmetric(horizontal: 8),
      ),
      dividerColor: borderColor,
      overlayColor:
          WidgetStateProperty.all(scheme.primary.withValues(alpha: 0.05)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
    ),
  );
}
