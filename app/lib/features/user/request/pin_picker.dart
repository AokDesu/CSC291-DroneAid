// C-13 MapPinPicker — modal route for picking a delivery pin on
// flutter_map (OpenStreetMap tiles). Used by P-U-03 home/request page.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'cart.dart';

/// Bangkok central — sensible default when the user has no profile address.
const _bangkokCenter = LatLng(13.7563, 100.5018);

/// Push the picker as a full-screen modal route. Returns the chosen pin or
/// null if the user backs out.
Future<DeliveryPin?> showPinPicker(
  BuildContext context, {
  DeliveryPin? initial,
}) {
  return Navigator.of(context).push<DeliveryPin>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PinPickerPage(initial: initial),
    ),
  );
}

class _PinPickerPage extends StatefulWidget {
  const _PinPickerPage({this.initial});
  final DeliveryPin? initial;

  @override
  State<_PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<_PinPickerPage> {
  late LatLng _pin;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial?.latLng ?? _bangkokCenter;
    _label = TextEditingController(text: widget.initial?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() => _pin = latlng);
  }

  void _save() {
    Navigator.of(context).pop(
      DeliveryPin(
        lat: _pin.latitude,
        lng: _pin.longitude,
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop a delivery pin'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _pin,
                initialZoom: 13,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'droneaid.csc291',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'Label (optional, e.g. "Home")',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
