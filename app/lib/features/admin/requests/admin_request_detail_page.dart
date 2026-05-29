// P-A-02 Admin Request Manage — approve / reject / drone picker.
// Spec: docs/09-page-flow-design.md §6 P-A-02.
// Backend: approveRequest, rejectRequest, assignDrone callables.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/drone_map.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reports/report.dart';
import '../../reports/reports_providers.dart';
import '../drones/drone.dart';
import '../drones/drone_providers.dart';
import 'admin_request.dart';
import 'admin_requests_provider.dart';
import 'eligibility.dart';

const _functionsRegion = 'asia-southeast1';

const _bg = Color(0xFFF6FAF9);
const _surface = Colors.white;
const _onMuted = Color(0xFF4A5957);
const _onFaint = Color(0xFF7A8987);
const _outlineSoft = Color(0xFFE3EBE9);
const _primary = Color(0xFF006A6A);
const _primarySoft = Color(0xFFD6F3F0);
const _coral = Color(0xFFC84B31);
const _coralSoft = Color(0xFFFFE2D8);
const _amber = Color(0xFFB58200);
const _sage = Color(0xFF2E7D5A);

class AdminRequestDetailPage extends ConsumerStatefulWidget {
  const AdminRequestDetailPage({super.key, required this.reqId});
  final String reqId;

  @override
  ConsumerState<AdminRequestDetailPage> createState() =>
      _AdminRequestDetailPageState();
}

class _AdminRequestDetailPageState
    extends ConsumerState<AdminRequestDetailPage> {
  String? _selectedDroneId;
  bool _busy = false;
  String? _serverError;

  Future<void> _runCallable(
    String name,
    Map<String, dynamic> payload, {
    required String successMessage,
    bool popOnSuccess = false,
  }) async {
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      await fns.httpsCallable(name).call<Map<String, dynamic>>(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      if (popOnSuccess) {
        context.go('/admin/requests');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqAsync = ref.watch(adminRequestDocProvider(widget.reqId));
    final names =
        ref.watch(userNamesProvider).valueOrNull ?? const <String, String>{};
    final dronesAsync = ref.watch(adminDronesStreamProvider);
    final reportsAsync = ref.watch(requestReportsProvider(widget.reqId));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Request'),
        backgroundColor: _bg,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/requests'),
        ),
      ),
      body: reqAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('Request not found.'));
          }
          final name = names[request.userId] ?? request.userId;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(request: request),
              const SizedBox(height: 16),
              _RequesterCard(name: name, userId: request.userId),
              const SizedBox(height: 12),
              _ItemsCard(request: request),
              const SizedBox(height: 12),
              _DeliveryCard(request: request),
              const SizedBox(height: 12),
              reportsAsync.maybeWhen(
                data: (reports) {
                  if (reports.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReportsCard(
                      reports: reports,
                      busy: _busy,
                      onResolve: (r) =>
                          _openResolveSheet(context, request.id, r),
                      onDismiss: (r) =>
                          _openDismissSheet(context, request.id, r),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              if (request.status == 'pending')
                _PendingActions(
                  onApprove: _busy
                      ? null
                      : () => _runCallable(
                            'approveRequest',
                            {'reqId': request.id},
                            successMessage:
                                'Approved. Pick a drone to assign.',
                          ),
                  onReject: _busy
                      ? null
                      : () => _openRejectDialog(context, request),
                )
              else if (request.status == 'approved' ||
                  request.status == 'failed')
                _DronePickerCard(
                  request: request,
                  dronesAsync: dronesAsync,
                  selectedDroneId: _selectedDroneId,
                  onSelect: (id) => setState(() => _selectedDroneId = id),
                  onAssign: (_busy || _selectedDroneId == null)
                      ? null
                      : () => _runCallable(
                            'assignDrone',
                            {
                              'reqId': request.id,
                              'droneId': _selectedDroneId,
                            },
                            successMessage:
                                'Drone dispatched. Tracking the flight.',
                            popOnSuccess: true,
                          ),
                )
              else if (request.status == 'in_flight')
                _InFlightCard(
                  onOpenControl: () => context.go('/admin/control'),
                  onRecall: (_busy || request.currentFlightId == null)
                      ? null
                      : () => _openRecallDialog(
                            context,
                            request.currentFlightId!,
                          ),
                )
              else
                _TerminalCard(request: request),
              if (_serverError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _serverError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _coral),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRejectDialog(
    BuildContext context,
    AdminRequest request,
  ) async {
    const reasons = [
      'Out of stock',
      'Weather too dangerous',
      'Out of service area',
      'Other',
    ];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pick a reason. The user will be notified.',
              style: TextStyle(fontSize: 13, color: _onMuted),
            ),
            const SizedBox(height: 12),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(r),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(r),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await _runCallable(
      'rejectRequest',
      {'reqId': request.id, 'reason': picked},
      successMessage: 'Request rejected: $picked.',
      popOnSuccess: true,
    );
  }

  Future<void> _openResolveSheet(
    BuildContext context,
    String reqId,
    Report report,
  ) async {
    final result = await showModalBottomSheet<_ResolveSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResolveSheet(report: report),
    );
    if (result == null) return;
    await _runCallable(
      'resolveReport',
      {
        'reqId': reqId,
        'reportId': report.id,
        'outcome': result.outcome.wire,
        'note': result.note,
      },
      successMessage: 'Report resolved: ${result.outcome.label}.',
    );
  }

  Future<void> _openRecallDialog(
    BuildContext context,
    String flightId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recall this flight?'),
        content: const Text(
          'The drone will turn around and head back to base. The '
          'request will be marked failed and the user will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: const Text('Recall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runCallable(
      'recallFlight',
      {'flightId': flightId},
      successMessage: 'Flight recalled. Drone returning to base.',
      popOnSuccess: true,
    );
  }

  Future<void> _openDismissSheet(
    BuildContext context,
    String reqId,
    Report report,
  ) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DismissSheet(report: report),
    );
    if (note == null) return;
    await _runCallable(
      'dismissReport',
      {'reqId': reqId, 'reportId': report.id, 'note': note},
      successMessage: 'Report dismissed.',
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request});
  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Request ',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Flexible(
              child: Text(
                '#${request.id}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: _onMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            StatusChip(status: request.status),
            if (request.priority == 'urgent') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _coralSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Urgent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _coral,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                request.createdAt == null
                    ? ''
                    : '· Submitted ${_fmtDateTime(request.createdAt!)}',
                style: const TextStyle(fontSize: 12, color: _onMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _fmtDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day} $h:$m';
}

Widget _shadowCard({required Widget child}) => Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14001E1E),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _onFaint,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _RequesterCard extends StatelessWidget {
  const _RequesterCard({required this.name, required this.userId});
  final String name;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Requester'),
            const SizedBox(height: 10),
            Row(
              children: [
                _Avatar(name: name, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: _onFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 32});
  final String name;
  final double size;

  static const _palette = <({Color bg, Color fg})>[
    (bg: Color(0xFFD4E8FA), fg: Color(0xFF0B6CB8)),
    (bg: Color(0xFFD2EFDF), fg: Color(0xFF2E7D5A)),
    (bg: Color(0xFFECE0FA), fg: Color(0xFF6B3FA0)),
    (bg: Color(0xFFFFF3D0), fg: Color(0xFFB58200)),
    (bg: Color(0xFFD6F3F0), fg: Color(0xFF006A6A)),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    int h = 0;
    for (final c in name.runes) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final cfg = _palette[h % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: cfg.fg,
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.request});
  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Items'),
            const SizedBox(height: 10),
            for (final it in request.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.catalogId,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '×${it.qty}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: _onMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: _outlineSoft),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total weight',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${request.totalWeightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.request});
  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    final lat = request.deliveryLat;
    final lng = request.deliveryLng;
    final hasCoord = lat != null && lng != null;
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Delivery'),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.place_outlined,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        request.deliveryLabel ?? 'No label',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasCoord) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _onFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hasCoord) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 180,
                  child: IgnorePointer(
                    child: DroneMap(
                      center: LatLng(lat, lng),
                      zoom: 14,
                      markers: [
                        DroneMapMarker(
                          id: request.id,
                          position: LatLng(lat, lng),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingActions extends StatelessWidget {
  const _PendingActions({
    required this.onApprove,
    required this.onReject,
  });
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('Action'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('approve-button'),
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('reject-button'),
                    onPressed: onReject,
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DronePickerCard extends StatelessWidget {
  const _DronePickerCard({
    required this.request,
    required this.dronesAsync,
    required this.selectedDroneId,
    required this.onSelect,
    required this.onAssign,
  });

  final AdminRequest request;
  final AsyncValue<List<Drone>> dronesAsync;
  final String? selectedDroneId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final isReassign = request.status == 'failed';
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(isReassign ? 'Reassign drone' : 'Pick a drone'),
            if (isReassign) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _coralSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Previous attempt failed (${request.rejectReason ?? "see log"}). Pick another drone.',
                  style: const TextStyle(fontSize: 13, color: _coral),
                ),
              ),
            ],
            const SizedBox(height: 12),
            dronesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                'Failed to load drones: $e',
                style: const TextStyle(color: _coral),
              ),
              data: (drones) {
                final lat = request.deliveryLat ?? 0;
                final lng = request.deliveryLng ?? 0;
                final rows = drones
                    .map((d) {
                      final e = eligibilityFor(
                        drone: d,
                        totalWeightKg: request.totalWeightKg,
                        destLat: lat,
                        destLng: lng,
                      );
                      return (drone: d, e: e);
                    })
                    .where((x) => x.e.ok || x.drone.status == 'idle')
                    .toList()
                  ..sort((a, b) {
                    final ad = a.e.distanceKm ?? 999;
                    final bd = b.e.distanceKm ?? 999;
                    if (ad != bd) return ad.compareTo(bd);
                    return b.drone.batteryPct.compareTo(a.drone.batteryPct);
                  });
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No eligible drone right now. Try again in a few minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _onMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DronePickerRow(
                          drone: row.drone,
                          eligibility: row.e,
                          selected: selectedDroneId == row.drone.id,
                          onSelect: () => onSelect(row.drone.id),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            FilledButton(
              key: const Key('assign-button'),
              onPressed: onAssign,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                selectedDroneId == null
                    ? 'Select a drone'
                    : 'Assign ${selectedDroneId!.toUpperCase()}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DronePickerRow extends StatelessWidget {
  const _DronePickerRow({
    required this.drone,
    required this.eligibility,
    required this.selected,
    required this.onSelect,
  });

  final Drone drone;
  final DroneEligibility eligibility;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ok = eligibility.ok;
    return Material(
      color: selected ? _primarySoft : _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('drone-${drone.id}'),
        onTap: ok ? onSelect : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primary : _outlineSoft,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _primary : const Color(0xFFC5D0CE),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.flight, size: 18, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      drone.name,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.battery_full,
                          size: 14,
                          color: drone.batteryPct < 30
                              ? _coral
                              : drone.batteryPct < 50
                                  ? _amber
                                  : _sage,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${drone.batteryPct}%',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: drone.batteryPct < 30
                                ? _coral
                                : drone.batteryPct < 50
                                    ? _amber
                                    : _sage,
                          ),
                        ),
                        if (eligibility.distanceKm != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${eligibility.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _onMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!ok)
                Row(
                  children: [
                    const Icon(Icons.close, size: 14, color: _coral),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        eligibility.reason ?? '',
                        style: const TextStyle(fontSize: 11, color: _coral),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else if (eligibility.warn)
                const Row(
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: _amber),
                    SizedBox(width: 4),
                    Text(
                      'low batt',
                      style: TextStyle(fontSize: 11, color: _amber),
                    ),
                  ],
                )
              else
                const Row(
                  children: [
                    Icon(Icons.check, size: 14, color: _sage),
                    SizedBox(width: 4),
                    Text(
                      'eligible',
                      style: TextStyle(fontSize: 11, color: _sage),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InFlightCard extends StatelessWidget {
  const _InFlightCard({
    required this.onOpenControl,
    required this.onRecall,
  });
  final VoidCallback onOpenControl;
  final VoidCallback? onRecall;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('In flight'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onOpenControl,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Open in Control map →'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('recall-button'),
              onPressed: onRecall,
              icon: const Icon(Icons.keyboard_return, color: _coral),
              label: const Text(
                'Recall drone',
                style: TextStyle(color: _coral),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _coral),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({required this.request});
  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Status'),
            const SizedBox(height: 10),
            Text(
              'This request is ${request.status}. No further action needed.',
              style: const TextStyle(fontSize: 13, color: _onMuted),
            ),
            if (request.rejectReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${request.rejectReason}',
                style: const TextStyle(fontSize: 13, color: _coral),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportsCard extends StatelessWidget {
  const _ReportsCard({
    required this.reports,
    required this.busy,
    required this.onResolve,
    required this.onDismiss,
  });

  final List<Report> reports;
  final bool busy;
  final ValueChanged<Report> onResolve;
  final ValueChanged<Report> onDismiss;

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('Reports'),
            const SizedBox(height: 10),
            for (var i = 0; i < reports.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: _outlineSoft),
                ),
              _ReportTile(
                report: reports[i],
                busy: busy,
                onResolve: () => onResolve(reports[i]),
                onDismiss: () => onDismiss(reports[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.busy,
    required this.onResolve,
    required this.onDismiss,
  });

  final Report report;
  final bool busy;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isOpen = report.status == ReportStatus.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ReportStatusChip(status: report.status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fmtDateTime(report.createdAt),
                style: const TextStyle(fontSize: 12, color: _onFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          report.message,
          style: const TextStyle(fontSize: 14),
        ),
        if (report.resolution != null || report.resolutionNote != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outlineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.resolution != null)
                  Text(
                    report.resolution!.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _onMuted,
                    ),
                  ),
                if (report.resolutionNote != null) ...[
                  if (report.resolution != null) const SizedBox(height: 2),
                  Text(
                    report.resolutionNote!,
                    style: const TextStyle(fontSize: 13, color: _onMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (isOpen) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: Key('resolve-${report.id}'),
                  onPressed: busy ? null : onResolve,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Resolve…'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: Key('dismiss-${report.id}'),
                  onPressed: busy ? null : onDismiss,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Dismiss…'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReportStatusChip extends StatelessWidget {
  const _ReportStatusChip({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late String label;
    switch (status) {
      case ReportStatus.open:
        bg = _coralSoft;
        fg = _coral;
        label = 'Open';
      case ReportStatus.resolved:
        bg = _primarySoft;
        fg = _primary;
        label = 'Resolved';
      case ReportStatus.dismissed:
        bg = const Color(0xFFEDEDED);
        fg = _onMuted;
        label = 'Dismissed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ResolveSheetResult {
  const _ResolveSheetResult({required this.outcome, required this.note});
  final ReportResolution outcome;
  final String note;
}

class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet({required this.report});
  final Report report;

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  ReportResolution? _outcome;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _outcome != null && _note.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resolve report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick the outcome and write a note. The user will see this.',
            style: TextStyle(fontSize: 13, color: _onMuted),
          ),
          const SizedBox(height: 16),
          _OutcomeRadio(
            value: ReportResolution.confirmWithRemedy,
            groupValue: _outcome,
            onChanged: (v) => setState(() => _outcome = v),
            title: 'Confirm with remedy',
            subtitle:
                'Delivery is accepted — replacement / late / minor issue. Request → confirmed.',
          ),
          const SizedBox(height: 8),
          _OutcomeRadio(
            value: ReportResolution.failDelivery,
            groupValue: _outcome,
            onChanged: (v) => setState(() => _outcome = v),
            title: 'Fail the delivery',
            subtitle:
                'Package never arrived / stolen / destroyed. Request → failed.',
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('resolve-note'),
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Note to user (required)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !canSubmit
                ? null
                : () => Navigator.of(context).pop(
                      _ResolveSheetResult(
                        outcome: _outcome!,
                        note: _note.text.trim(),
                      ),
                    ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Resolve report'),
          ),
        ],
      ),
    );
  }
}

class _OutcomeRadio extends StatelessWidget {
  const _OutcomeRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final ReportResolution value;
  final ReportResolution? groupValue;
  final ValueChanged<ReportResolution?> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _primarySoft : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _primary : _outlineSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<ReportResolution>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _onMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissSheet extends StatefulWidget {
  const _DismissSheet({required this.report});
  final Report report;

  @override
  State<_DismissSheet> createState() => _DismissSheetState();
}

class _DismissSheetState extends State<_DismissSheet> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _note.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dismiss report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Write a note explaining why no action will be taken. The user will see this.',
            style: TextStyle(fontSize: 13, color: _onMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('dismiss-note'),
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Note to user (required)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !canSubmit
                ? null
                : () => Navigator.of(context).pop(_note.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Dismiss report'),
          ),
        ],
      ),
    );
  }
}

