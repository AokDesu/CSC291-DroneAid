import 'package:droneaid/core/widgets/drone_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const bangkok = LatLng(13.7563, 100.5018);

  Future<void> pumpMap(
    WidgetTester tester, {
    List<DroneMapMarker> markers = const [],
    void Function(LatLng)? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: DroneMap(
              center: bangkok,
              markers: markers,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  group('DroneMap', () {
    testWidgets('renders a FlutterMap with TileLayer + MarkerLayer', (tester) async {
      await pumpMap(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('passes markers through to MarkerLayer', (tester) async {
      await pumpMap(
        tester,
        markers: const [
          DroneMapMarker(id: 'a', position: LatLng(13.7, 100.5)),
          DroneMapMarker(id: 'b', position: LatLng(13.8, 100.6)),
        ],
      );
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers.length, 2);
    });

    testWidgets('forwards map taps to onTap callback', (tester) async {
      LatLng? tapped;
      await pumpMap(tester, onTap: (p) => tapped = p);

      // Reach into MapOptions and invoke its onTap directly — the gesture
      // pipeline inside flutter_map is awkward to drive from a widget test.
      final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
      const point = LatLng(13.9, 100.7);
      mapWidget.options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        point,
      );

      expect(tapped, point);
    });

    testWidgets('does not wire onTap when callback is null', (tester) async {
      await pumpMap(tester);
      final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapWidget.options.onTap, isNull);
    });
  });
}
