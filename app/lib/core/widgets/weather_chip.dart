// Shared AppBar weather chip. Streams `weather/current` and renders an
// icon + label pill. Tap → /admin/weather for admins, no-op for users.
//
// Spec: docs/09-page-flow-design.md §3 (shell AppBar) + C-15.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/weather/weather.dart';
import '../../features/admin/weather/weather_providers.dart';
import '../auth/auth_providers.dart';
import '../tokens.dart';

class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherStreamProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasError = async.hasError && !async.isLoading;
    final state = async.valueOrNull?.state ?? 'clear';
    final isAdmin = profile?.isAdmin ?? false;
    final t = Theme.of(context);

    final icon = hasError ? Icons.cloud_off : iconFor(state);
    final label = hasError ? 'Offline' : labelFor(state);
    final fg = hasError
        ? t.colorScheme.onSurfaceVariant
        : t.colorScheme.onSurface;
    final bg = t.brightness == Brightness.dark
        ? const Color(0xFF1F242B)
        : const Color(0xFFF2F4F8);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: isAdmin
          ? InkWell(
              borderRadius: BorderRadius.circular(AppRadii.chip),
              onTap: () => context.go('/admin/weather'),
              child: chip,
            )
          : chip,
    );
  }

  static IconData iconFor(String state) {
    switch (state) {
      case 'storm':
        return Icons.thunderstorm;
      case 'wind':
        return Icons.air;
      case 'clear':
      default:
        return Icons.wb_sunny;
    }
  }

  static String labelFor(String state) {
    return weatherOptions
        .firstWhere(
          (o) => o.state == state,
          orElse: () => WeatherOption(state: state, label: state, detail: ''),
        )
        .label;
  }
}

/// Compact glyph (icon only) version used inside AppBarAction containers
/// in the admin shell. No background — the wrapper supplies it.
class WeatherChipGlyph extends ConsumerWidget {
  const WeatherChipGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherStreamProvider);
    final state = async.valueOrNull?.state ?? 'clear';
    final hasError = async.hasError && !async.isLoading;
    return Icon(
      hasError ? Icons.cloud_off : WeatherChip.iconFor(state),
      size: size,
    );
  }
}
