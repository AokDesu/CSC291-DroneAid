// C-13 MapPinPicker — modal route for picking a pin on flutter_map
// (OpenStreetMap tiles). Used by P-U-03 home/request page (delivery
// pin) and by the admin Profile page (hub location).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'cart.dart';

/// Bangkok central — sensible default when there's no prior pin.
const _bangkokCenter = LatLng(13.7563, 100.5018);

/// Push the picker as a full-screen modal route. Returns the chosen pin or
/// null if the user backs out. Title + label-field hint are parameterised
/// so callers can re-purpose this for non-delivery pins (e.g. admin Hub).
Future<DeliveryPin?> showPinPicker(
  BuildContext context, {
  DeliveryPin? initial,
  String title = 'Drop a delivery pin',
  String labelFieldLabel = 'Label (optional, e.g. "Home")',
}) {
  return Navigator.of(context).push<DeliveryPin>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PinPickerPage(
        initial: initial,
        title: title,
        labelFieldLabel: labelFieldLabel,
      ),
    ),
  );
}

class _PinPickerPage extends StatefulWidget {
  const _PinPickerPage({
    this.initial,
    required this.title,
    required this.labelFieldLabel,
  });
  final DeliveryPin? initial;
  final String title;
  final String labelFieldLabel;

  @override
  State<_PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<_PinPickerPage> {
  late LatLng _pin;
  late final TextEditingController _label;
  final MapController _mapController = MapController();
  bool _gpsBusy = false;

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

  Future<void> _useGps() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _gpsBusy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are off. Enable them and try again.',
            ),
          ),
        );
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Enable it in system settings.',
            ),
          ),
        );
        return;
      }
      if (perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      final next = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = next);
      _mapController.move(next, 15);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
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
        title: Text(widget.title),
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
              mapController: _mapController,
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('pin-picker-gps'),
                  onPressed: _gpsBusy ? null : _useGps,
                  icon: _gpsBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Use my location'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _label,
                  decoration: InputDecoration(
                    labelText: widget.labelFieldLabel,
                    border: const OutlineInputBorder(),
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
