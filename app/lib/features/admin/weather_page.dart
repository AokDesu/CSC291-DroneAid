// P-A-06 Admin Weather panel.
// Spec: docs/09-page-flow-design.md §6 P-A-06.
// Backend: streams `weather/current`; writes via `setWeather` admin callable.
// Flow: F-22.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/section_label.dart';
import 'weather/weather.dart';
import 'weather/weather_providers.dart';

const _functionsRegion = 'asia-southeast1';

/// Pure helper — friendly label for a state string. Falls through to the raw
/// value so unknown enums still render *something* instead of blank.
@visibleForTesting
String weatherLabel(String state) {
  return weatherOptions
      .firstWhere(
        (o) => o.state == state,
        orElse: () => WeatherOption(state: state, label: state, detail: ''),
      )
      .label;
}

/// Pure helper — detail line for a state.
@visibleForTesting
String weatherDetail(String state) {
  return weatherOptions
      .firstWhere(
        (o) => o.state == state,
        orElse: () => const WeatherOption(state: '', label: '', detail: ''),
      )
      .detail;
}

/// Pure helper — the Save button is disabled when the chosen draft equals the
/// server's current state. Prevents no-op writes.
@visibleForTesting
bool canSave({required String? draft, required String current}) {
  return draft != null && draft != current;
}

class AdminWeatherPage extends ConsumerStatefulWidget {
  const AdminWeatherPage({super.key});

  @override
  ConsumerState<AdminWeatherPage> createState() => _AdminWeatherPageState();
}

class _AdminWeatherPageState extends ConsumerState<AdminWeatherPage> {
  String? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weatherStreamProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load weather: $e')),
        data: (weather) => _Body(
          weather: weather,
          draft: _draft ?? weather.state,
          saving: _saving,
          onPick: (s) => setState(() => _draft = s),
          onSave: () => _save(weather.state),
        ),
      ),
    );
  }

  Future<void> _save(String currentState) async {
    final next = _draft;
    if (!canSave(draft: next, current: currentState)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      await fns
          .httpsCallable('setWeather')
          .call<Map<String, dynamic>>({'state': next});
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Weather set to ${weatherLabel(next!)}.')),
      );
      setState(() => _draft = null); // re-sync to server value
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.weather,
    required this.draft,
    required this.saving,
    required this.onPick,
    required this.onSave,
  });

  final Weather weather;
  final String draft;
  final bool saving;
  final ValueChanged<String> onPick;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saveEnabled = !saving && canSave(draft: draft, current: weather.state);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const PageHeader(
          eyebrow: 'P-A-06 · WEATHER',
          title: 'Weather',
          subtitle:
              'Affects speed, battery drain, and abort risk for all in-flight drones.',
        ),
        const SectionLabel('CURRENT STATE'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconFor(weather.state),
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          weatherLabel(weather.state),
                          key: const Key('weather-current-label'),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _updatedLine(weather),
                    key: const Key('weather-updated-line'),
                    style: context.appText.mono,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionLabel('SET STATE'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Card(
            child: RadioGroup<String>(
              groupValue: draft,
              onChanged: (v) {
                if (saving || v == null) return;
                onPick(v);
              },
              child: Column(
                children: [
                  for (var i = 0; i < weatherOptions.length; i++) ...[
                    RadioListTile<String>(
                      key: Key('weather-option-${weatherOptions[i].state}'),
                      value: weatherOptions[i].state,
                      title: Text(weatherOptions[i].label),
                      subtitle: Text(weatherOptions[i].detail),
                    ),
                    if (i < weatherOptions.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (draft == 'storm')
          Container(
            key: const Key('weather-storm-warning'),
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Storm immediately recalls in-flight drones; new '
                    'flights are blocked. Mid-flight: ~3% extra abort '
                    'chance per tick.',
                    style: TextStyle(color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('weather-save'),
              onPressed: saveEnabled ? onSave : null,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  IconData _iconFor(String state) {
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

  String _updatedLine(Weather w) {
    if (w.updatedAt == null) return 'Never updated';
    final ts = DateFormat('MMM d, h:mm a').format(w.updatedAt!.toLocal());
    final by = (w.updatedBy ?? '').isEmpty ? 'unknown' : w.updatedBy!;
    return 'Updated $ts by $by';
  }
}
