// Public API frozen per #23 / ADR-0003. Body filled in #24.

import 'package:flutter/material.dart';
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
    return Container(color: Colors.grey);
  }
}
