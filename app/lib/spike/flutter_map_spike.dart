// PROTOTYPE — throwaway for issue #28. DELETE after P-U-05 verdict.
// Question: do OSM tiles + flutter_map 7.0.2 work on Android emulator?
// Can we smoothly lerp a drone marker between positions (simulating 60s server ticks)?

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Two Bangkok waypoints ~3 km apart — Silom ↔ Lat Phrao
const _a = LatLng(13.7563, 100.5018);
const _b = LatLng(13.7937, 100.5323);

class FlutterMapSpikePage extends StatefulWidget {
  const FlutterMapSpikePage({super.key});

  @override
  State<FlutterMapSpikePage> createState() => _FlutterMapSpikePageState();
}

class _FlutterMapSpikePageState extends State<FlutterMapSpikePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _forward = true;

  LatLng get _pos {
    final t = _ctrl.value;
    return LatLng(
      _a.latitude + (_b.latitude - _a.latitude) * t,
      _a.longitude + (_b.longitude - _a.longitude) * t,
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _forward = false;
          _ctrl.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _forward = true;
          _ctrl.forward();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    return Scaffold(
      appBar: AppBar(
        title: const Text('[SPIKE] flutter_map — issue #28'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(13.775, 100.517),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.droneaid.app',
              ),
              MarkerLayer(
                markers: [
                  // Waypoint A — blue
                  Marker(
                    point: _a,
                    width: 16,
                    height: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Waypoint B — green
                  Marker(
                    point: _b,
                    width: 16,
                    height: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Drone — animated red airplane
                  Marker(
                    point: pos,
                    width: 44,
                    height: 44,
                    child: Transform.rotate(
                      angle: _forward ? 0.5 : -0.5,
                      child: const Icon(
                        Icons.airplanemode_active,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // State overlay — surfaces full state per prototype rule #5
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('lat: ${pos.latitude.toStringAsFixed(5)}'
                          '  lng: ${pos.longitude.toStringAsFixed(5)}'),
                      Text(
                        'progress: ${(_ctrl.value * 100).toStringAsFixed(1)}%'
                        '  dir: ${_forward ? "A→B (Silom→Lat Phrao)" : "B→A (Lat Phrao→Silom)"}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
