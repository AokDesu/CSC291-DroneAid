// Domain model for the singleton `weather/current` doc. Schema mirrors
// `functions/src/callable/setWeather.ts`.

import 'package:cloud_firestore/cloud_firestore.dart';

class Weather {
  const Weather({
    required this.state,
    this.updatedBy,
    this.updatedAt,
  });

  /// `clear` | `wind` | `storm`. Server-side enum guards via Zod, so we treat
  /// any other value as `clear` and let the page render a default.
  final String state;
  final String? updatedBy;
  final DateTime? updatedAt;

  factory Weather.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    final ts = data['updatedAt'];
    return Weather(
      state: (data['state'] as String?) ?? 'clear',
      updatedBy: data['updatedBy'] as String?,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Pure spec-table — what each state means for the sim engine. Display-only;
/// the real math lives in `functions/src/lib/sim.ts` + `weather.ts`.
class WeatherOption {
  const WeatherOption({
    required this.state,
    required this.label,
    required this.detail,
  });

  final String state;
  final String label;
  final String detail;
}

const weatherOptions = <WeatherOption>[
  WeatherOption(
    state: 'clear',
    label: 'Clear',
    detail: 'Mod ×1.0 · drain 80%/hr',
  ),
  WeatherOption(
    state: 'wind',
    label: 'Wind',
    detail: 'Mod ×0.7 · drain 100%/hr · 3% abort risk',
  ),
  WeatherOption(
    state: 'storm',
    label: 'Storm',
    detail: 'Mod ×0.0 · drain 120%/hr · 20% abort risk',
  ),
];
