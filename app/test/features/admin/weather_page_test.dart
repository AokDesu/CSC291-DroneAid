// Unit + widget tests for P-A-06 weather panel.

import 'package:droneaid/features/admin/weather/weather.dart';
import 'package:droneaid/features/admin/weather/weather_providers.dart';
import 'package:droneaid/features/admin/weather_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weatherLabel', () {
    test('maps known states to spec copy', () {
      expect(weatherLabel('clear'), 'Clear');
      expect(weatherLabel('wind'), 'Wind');
      expect(weatherLabel('storm'), 'Storm');
    });

    test('falls through to raw value for unknown', () {
      expect(weatherLabel('blizzard'), 'blizzard');
    });
  });

  group('weatherDetail', () {
    test('includes mod + drain copy', () {
      expect(weatherDetail('clear'), contains('×1.0'));
      expect(weatherDetail('wind'), contains('×0.7'));
      expect(weatherDetail('storm'), contains('20% abort'));
    });
  });

  group('canSave', () {
    test('false when draft is null', () {
      expect(canSave(draft: null, current: 'clear'), isFalse);
    });
    test('false when draft equals current', () {
      expect(canSave(draft: 'clear', current: 'clear'), isFalse);
    });
    test('true when draft differs from current', () {
      expect(canSave(draft: 'storm', current: 'clear'), isTrue);
    });
  });

  group('AdminWeatherPage widgets', () {
    testWidgets('renders current state and updated line', (tester) async {
      await _pump(
        tester,
        weather: Weather(
          state: 'clear',
          updatedBy: 'admin-uid',
          updatedAt: DateTime(2026, 5, 24, 19, 12),
        ),
      );

      expect(find.byKey(const Key('weather-current-label')), findsOneWidget);
      expect(find.text('Clear'), findsWidgets);
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(find.textContaining('admin-uid'), findsOneWidget);
    });

    testWidgets('shows "Never updated" when no timestamp', (tester) async {
      await _pump(tester, weather: const Weather(state: 'clear'));
      expect(find.text('Never updated'), findsOneWidget);
    });

    testWidgets('renders three radio options', (tester) async {
      await _pump(tester, weather: const Weather(state: 'clear'));
      expect(find.byKey(const Key('weather-option-clear')), findsOneWidget);
      expect(find.byKey(const Key('weather-option-wind')), findsOneWidget);
      expect(find.byKey(const Key('weather-option-storm')), findsOneWidget);
    });

    testWidgets('Save button disabled when draft equals current',
        (tester) async {
      await _pump(tester, weather: const Weather(state: 'clear'));
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('weather-save')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('selecting Storm enables Save and shows warning banner',
        (tester) async {
      await _pump(tester, weather: const Weather(state: 'clear'));

      await tester.tap(find.byKey(const Key('weather-option-storm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weather-storm-warning')), findsOneWidget);
      expect(find.textContaining('Storm immediately recalls'), findsOneWidget);

      // Save button is below the fold after the storm warning expands;
      // scroll it into view before inspecting its onPressed state.
      await tester.scrollUntilVisible(
        find.byKey(const Key('weather-save')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('weather-save')),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('no warning banner when draft is not Storm', (tester) async {
      await _pump(tester, weather: const Weather(state: 'clear'));
      await tester.tap(find.byKey(const Key('weather-option-wind')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weather-storm-warning')), findsNothing);
    });
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Weather weather,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherStreamProvider.overrideWith((ref) => Stream.value(weather)),
      ],
      child: const MaterialApp(home: AdminWeatherPage()),
    ),
  );
  await tester.pumpAndSettle();
}
