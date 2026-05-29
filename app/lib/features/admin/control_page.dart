// P-A-05 Admin Control live map — "god view" of all active flights.
// Spec: docs/09-page-flow-design.md §6 P-A-05.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/widgets/drone_map.dart';
import '../../core/widgets/status_chip.dart';
import '../user/tracking/flight_provider.dart';
import '../user/tracking/interpolation.dart';
import 'control/control_providers.dart';

const _base = LatLng(13.74, 100.54); // Bangkok warehouse fallback center
const _functionsRegion = 'asia-southeast1';

class ControlPage extends ConsumerStatefulWidget {
  const ControlPage({super.key});

  @override
  ConsumerState<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends ConsumerState<ControlPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _ticker.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _tickNow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      final result = await fns
          .httpsCallable('devTickFlights')
          .call<Map<String, dynamic>>();
      final count = (result.data['count'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ticked $count active flight${count == 1 ? '' : 's'}.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Tick failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Tick failed: $e')));
    }
  }

  void _showSheet(BuildContext context, FlightDoc flight) {
    final now = DateTime.now();
    final snap = flightSnapshot(
      origin: flight.origin,
      destination: flight.destination,
      takeoffAt: flight.takeoffAt,
      speedKmh: flight.speedKmh,
      weatherModifier: flight.weatherModifier,
      batteryAtTakeoff: flight.batteryAtTakeoff,
      now: now,
    );
    final eta = etaRemaining(flight.etaAt, now);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  flight.droneId.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                StatusChip(status: flight.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('ETA: ${etaLabel(eta)}'),
            Text('Battery: ${snap.battery.round()}%'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/admin/requests/${flight.requestId}');
              },
              child: const Text('View request →'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flightsAsync = ref.watch(activeFlightsProvider);

    return Scaffold(
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              key: const Key('dev-tick-now'),
              onPressed: _tickNow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Tick now'),
            )
          : null,
      body: flightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading flights: $e')),
        data: (flights) {
          final now = DateTime.now();

          final markers = <DroneMapMarker>[
            for (final flight in flights)
              () {
                final snap = flightSnapshot(
                  origin: flight.origin,
                  destination: flight.destination,
                  takeoffAt: flight.takeoffAt,
                  speedKmh: flight.speedKmh,
                  weatherModifier: flight.weatherModifier,
                  batteryAtTakeoff: flight.batteryAtTakeoff,
                  now: now,
                );
                final pos = dronePosition(
                  status: flight.status,
                  origin: flight.origin,
                  destination: flight.destination,
                  progress: snap.progress,
                );
                return DroneMapMarker(
                  id: flight.id,
                  position: pos,
                  icon: GestureDetector(
                    onTap: () => _showSheet(context, flight),
                    child: const Icon(
                      Icons.airplanemode_active,
                      color: Colors.deepOrange,
                      size: 32,
                    ),
                  ),
                );
              }(),
          ];

          final center = markers.isNotEmpty ? markers.first.position : _base;

          return Stack(
            children: [
              DroneMap(
                center: center,
                zoom: 13.0,
                markers: markers,
              ),
              if (flights.isEmpty)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Text('No drones in flight.'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
