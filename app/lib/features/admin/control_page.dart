// P-A-05 Admin Control live map — "god view" of all active flights.
// Spec: docs/09-page-flow-design.md §6 P-A-05.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/widgets/drone_map.dart';
import '../../core/widgets/status_chip.dart';
import '../user/tracking/flight_provider.dart';
import '../user/tracking/interpolation.dart';
import 'control/control_providers.dart';
import 'drones/drone_providers.dart';

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
  Timer? _autoTickTimer;

  /// Emulator suite doesn't fire scheduled triggers, so the production
  /// 1-minute tickFlights cron never runs locally. While ControlPage is
  /// mounted, drive the same loop via devTickFlights every 15 s so
  /// returning drones land and flip back to `idle` without admin having
  /// to mash the manual FAB.
  static const _autoTickInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _ticker.addListener(() => setState(() {}));
    _autoTickTimer = Timer.periodic(
      _autoTickInterval,
      (_) => _tickNow(silent: true),
    );
  }

  @override
  void dispose() {
    _autoTickTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _tickNow({bool silent = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      final result = await fns
          .httpsCallable('devTickFlights')
          .call<Map<String, dynamic>>();
      if (silent) return;
      final count = (result.data['count'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ticked $count active flight${count == 1 ? '' : 's'}.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (silent) return;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Tick failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (silent) return;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Tick failed: $e')));
    }
  }

  static const _recallableStatuses = {'enroute', 'delivering'};

  Future<void> _recall(FlightDoc flight) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recall this flight?'),
        content: const Text(
          'The drone will turn around and head back to base. The request '
          'will be marked failed and the user will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      await fns
          .httpsCallable('recallFlight')
          .call<Map<String, dynamic>>({'flightId': flight.id});
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Flight recalled. Drone returning.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Recall failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Recall failed: $e')));
    }
  }

  Future<void> _collectDrone(FlightDoc flight) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collect this drone?'),
        content: const Text(
          'Skips the return-trip simulation. The drone enters maintenance '
          'with the round-trip battery drain applied. Use this when you '
          'do not want to wait the simulated travel time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Collect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      await fns
          .httpsCallable('collectDrone')
          .call<Map<String, dynamic>>({'droneId': flight.droneId});
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Drone collected. Now in maintenance.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Collect failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Collect failed: $e')));
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
    final canRecall = _recallableStatuses.contains(flight.status);
    final canCollect = flight.status == 'returning';

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
            if (canRecall)
              TextButton(
                key: Key('recall-${flight.id}'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _recall(flight);
                },
                child: const Text('Recall drone'),
              ),
            if (canCollect)
              TextButton.icon(
                key: Key('collect-${flight.id}'),
                onPressed: () {
                  Navigator.pop(context);
                  _collectDrone(flight);
                },
                icon: const Icon(Icons.flight_land),
                label: const Text('Collect drone (skip return trip)'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flightsAsync = ref.watch(activeFlightsProvider);
    final drones = ref.watch(adminDronesStreamProvider).valueOrNull ??
        const <dynamic>[];

    // Dedupe drone baseLocations to a ~5-decimal grid so floating-point
    // noise from Firestore doesn't produce N near-identical pins. Retired
    // drones don't contribute a hub.
    final seenBases = <String>{};
    final hubMarkers = <DroneMapMarker>[];
    for (final d in drones) {
      if (d.status == 'retired') continue;
      final key =
          '${d.baseLat.toStringAsFixed(5)},${d.baseLng.toStringAsFixed(5)}';
      if (!seenBases.add(key)) continue;
      hubMarkers.add(
        DroneMapMarker(
          id: 'hub-$key',
          position: LatLng(d.baseLat, d.baseLng),
          icon: const Icon(
            Icons.warehouse_outlined,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dev-tick-now'),
        onPressed: () => _tickNow(),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Tick now'),
      ),
      body: flightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading flights: $e')),
        data: (flights) {
          final now = DateTime.now();

          final flightMarkers = <DroneMapMarker>[
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

          // Hubs first so drone aircraft icons render on top.
          final markers = <DroneMapMarker>[...hubMarkers, ...flightMarkers];

          final center = flightMarkers.isNotEmpty
              ? flightMarkers.first.position
              : (hubMarkers.isNotEmpty ? hubMarkers.first.position : _base);

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
