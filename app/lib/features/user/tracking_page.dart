// P-U-05 — Live Tracking. Spec: docs/09-page-flow-design.md §5 P-U-05.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/firebase_errors.dart';
import '../../core/widgets/battery_bar.dart';
import '../../core/widgets/drone_map.dart';
import '../../core/widgets/status_chip.dart';
import 'tracking/flight_provider.dart';
import 'tracking/interpolation.dart';

const _functionsRegion = 'asia-southeast1';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({required this.flightId, super.key});

  final String flightId;

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // Drives per-frame rebuilds for smooth drone marker movement.
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flightAsync = ref.watch(flightStreamProvider(widget.flightId));

    // Auto-redirect to P-U-06 when flight reaches completed state.
    ref.listen(flightStreamProvider(widget.flightId), (_, next) {
      next.whenData((flight) {
        if (flight != null && flight.status == 'completed' && mounted) {
          context.go('/user/confirm/${flight.requestId}');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: flightAsync.whenOrNull(
              data: (f) => f != null
                  ? Text('Tracking #${f.requestId.length > 8 ? f.requestId.substring(0, 8) : f.requestId}')
                  : null,
            ) ??
            const Text('Tracking'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/user/queue'),
        ),
      ),
      body: flightAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _ErrorState(message: 'Flight not found.'),
        data: (flight) {
          if (flight == null) {
            return const _ErrorState(message: 'Flight not found.');
          }
          return AnimatedBuilder(
            animation: _ticker,
            builder: (context, _) => _TrackingBody(flight: flight),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.flight});

  final FlightDoc flight;

  @override
  Widget build(BuildContext context) {
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

    final dronePos = dronePosition(
      status: flight.status,
      origin: flight.origin,
      destination: flight.destination,
      progress: snap.progress,
    );

    final mapCenter = LatLng(
      (flight.origin.latitude + flight.destination.latitude) / 2,
      (flight.origin.longitude + flight.destination.longitude) / 2,
    );

    final hasArrived = (flight.status == 'enroute' && snap.progress >= 1.0) ||
        flight.status == 'delivering';

    return Column(
      children: [
        if (hasArrived) _ArrivalCta(reqId: flight.requestId),
        _StatusBanner(
          status: flight.status,
          failureType: flight.failureType,
        ),
        Expanded(
          child: DroneMap(
            center: mapCenter,
            zoom: 13.0,
            markers: [
              DroneMapMarker(
                id: 'origin',
                position: flight.origin,
                icon: const Icon(Icons.warehouse_outlined,
                    color: Colors.blue, size: 32,),
              ),
              DroneMapMarker(
                id: 'destination',
                position: flight.destination,
                icon: const Icon(Icons.location_on,
                    color: Colors.green, size: 32,),
              ),
              DroneMapMarker(
                id: 'drone',
                position: dronePos,
                icon: _droneIcon(flight.status),
              ),
            ],
          ),
        ),
        _InfoPanel(
          flight: flight,
          battery: snap.battery,
          eta: etaRemaining(flight.etaAt, now),
        ),
      ],
    );
  }
}

Widget _droneIcon(String status) {
  if (status == 'aborted' || status == 'failed') {
    return const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32);
  }
  return const Icon(Icons.flight, color: Colors.deepOrange, size: 32);
}

// ---------------------------------------------------------------------------
// Status banner
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, this.failureType});

  final String status;
  final String? failureType;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      'enroute' => ('In flight', Colors.green),
      'delivering' => ('Arriving — get ready', Colors.amber),
      'completed' => ('Delivered — please confirm', Colors.blue),
      'returning' => ('Returning to base', Colors.grey),
      'aborted' || 'failed' => (
          'Flight aborted: ${failureType ?? 'unknown'}',
          Colors.red
        ),
      _ => (status, Colors.grey),
    };

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14,),),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info panel
// ---------------------------------------------------------------------------

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.flight,
    required this.battery,
    required this.eta,
  });

  final FlightDoc flight;
  final double battery;
  final Duration eta;

  @override
  Widget build(BuildContext context) {
    final distKm =
        haversineKm(flight.origin, flight.destination).toStringAsFixed(1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Status',
                        style: TextStyle(color: Colors.black54, fontSize: 13,),),
                    const Spacer(),
                    StatusChip(status: flight.status),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'ETA',
                  value: etaLabel(eta),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(
                      width: 72,
                      child: Text('Battery',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13,),),
                    ),
                    Expanded(child: BatteryBar(percent: battery)),
                    const SizedBox(width: 8),
                    Text('${battery.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 13,),),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Weather',
                  value: weatherLabel(flight.weatherModifier),
                ),
                _InfoRow(
                  label: 'Speed',
                  value:
                      '${flight.speedKmh.toStringAsFixed(0)} km/h',
                ),
                _InfoRow(label: 'Distance', value: '$distKm km total'),
                if (flight.status == 'aborted' ||
                    flight.status == 'failed') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/user/queue'),
                      child: const Text('Back to Queue'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13,),),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arrival CTA — visible when the drone is at the destination, before the
// server tick has flipped the request through delivered → confirmed.
// Tapping invokes confirmDelivery which collapses delivered + confirmed
// into one transition (server re-validates arrival math).
// ---------------------------------------------------------------------------

class _ArrivalCta extends StatefulWidget {
  const _ArrivalCta({required this.reqId});
  final String reqId;

  @override
  State<_ArrivalCta> createState() => _ArrivalCtaState();
}

class _ArrivalCtaState extends State<_ArrivalCta> {
  bool _confirming = false;

  Future<void> _confirm() async {
    // Capture inherited refs before await so the post-await path doesn't
    // dereference a context that has already started teardown.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _confirming = true);
    try {
      await FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable('confirmDelivery')
          .call<Map<String, dynamic>>({'reqId': widget.reqId});
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks — supplies received.')),
      );
      // Defer navigation past the current frame so the Firestore stream
      // emission (flight.status → returning, which removes this CTA from
      // the parent Column) doesn't race with the route swap. Without the
      // post-frame hop the simultaneous tree mutations can trip a Flutter
      // inherited-element assertion during the rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go('/user/queue');
      });
      return;
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not confirm: ${describeFunctionsError(e)}')),
      );
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your supplies have arrived.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('arrival-confirm'),
            onPressed: _confirming ? null : _confirm,
            icon: _confirming
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text("I've received the supplies"),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/user/queue'),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
