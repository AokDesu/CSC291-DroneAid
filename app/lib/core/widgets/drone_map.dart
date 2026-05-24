// Public API frozen per #23 / ADR-0003.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DroneMapMarker {
  const DroneMapMarker({
    required this.id,
    required this.position,
    this.icon,
  });

  final String id;
  final LatLng position;
  final Widget? icon;
}

class DroneMap extends StatelessWidget {
  const DroneMap({
    super.key,
    required this.center,
    this.zoom = 13.0,
    this.markers = const [],
    this.onTap,
  });

  final LatLng center;
  final double zoom;
  final List<DroneMapMarker> markers;
  final void Function(LatLng)? onTap;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'droneaid.csc291',
        ),
        MarkerLayer(
          markers: [
            for (final m in markers)
              Marker(
                point: m.position,
                width: 40,
                height: 40,
                child: m.icon ??
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 32,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}
