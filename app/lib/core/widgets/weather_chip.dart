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

class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherStreamProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasError = async.hasError && !async.isLoading;
    final state = async.valueOrNull?.state ?? 'clear';
    final isAdmin = profile?.isAdmin ?? false;
    final theme = Theme.of(context);

    final icon = hasError ? Icons.cloud_off : _iconFor(state);
    final label = hasError ? 'Offline' : _labelFor(state);
    final fg = hasError
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final bg = hasError
        ? theme.colorScheme.surfaceContainerHighest
        : null;

    final chip = Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg),
      ),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: isAdmin
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/admin/weather'),
              child: chip,
            )
          : chip,
    );
  }

  static IconData _iconFor(String state) {
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

  static String _labelFor(String state) {
    return weatherOptions
        .firstWhere(
          (o) => o.state == state,
          orElse: () => WeatherOption(state: state, label: state, detail: ''),
        )
        .label;
  }
}
