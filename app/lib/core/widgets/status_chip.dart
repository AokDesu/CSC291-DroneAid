// Status pill — bullet-dot prefix for soft statuses (pending, in_flight),
// filled-pill for urgent. Colors pulled from AppStatusColors ThemeExtension.
// Public API frozen per #23 / ADR-0003: prop `status` unchanged.

import 'package:flutter/material.dart';

import '../theme_extensions.dart';
import '../tokens.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.padding,
    this.dense = false,
  });

  final String status;
  final EdgeInsets? padding;
  final bool dense;

  /// Back-compat shim for code that still reads `StatusChip.colorFor(...)`.
  /// Returns the foreground color of the new palette.
  static Color colorFor(String status) {
    final s = _StatusStyle.forStatus(status, AppStatusColors.light);
    return s.fg;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.statusColors;
    final style = _StatusStyle.forStatus(status, palette);
    final padded = padding ??
        EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 4,
        );

    return Container(
      padding: padded,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.dot)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: style.fg,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Text(
            _labelFor(status),
            style: TextStyle(
              color: style.fg,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: style.allCaps ? 0.5 : 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(String status) {
    switch (status) {
      case 'in_flight':
      case 'enroute':
        return 'In flight';
      case 'delivering':
        return 'Delivering';
      case 'returning':
        return 'Returning';
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'assigned':
        return 'Assigned';
      case 'delivered':
        return 'Delivered';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'aborted':
        return 'Aborted';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'urgent':
        return 'URGENT';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.bg,
    required this.fg,
    required this.dot,
    this.allCaps = false,
  });
  final Color bg;
  final Color fg;
  final bool dot;
  final bool allCaps;

  factory _StatusStyle.forStatus(String status, AppStatusColors p) {
    switch (status) {
      case 'pending':
        return _StatusStyle(bg: p.pendingBg, fg: p.pendingFg, dot: true);
      case 'approved':
      case 'assigned':
        return _StatusStyle(bg: p.approvedBg, fg: p.approvedFg, dot: true);
      case 'in_flight':
      case 'enroute':
      case 'delivering':
      case 'returning':
        return _StatusStyle(bg: p.inFlightBg, fg: p.inFlightFg, dot: true);
      case 'delivered':
        return _StatusStyle(bg: p.deliveredBg, fg: p.deliveredFg, dot: true);
      case 'confirmed':
      case 'completed':
        return _StatusStyle(bg: p.confirmedBg, fg: p.confirmedFg, dot: true);
      case 'failed':
      case 'aborted':
        return _StatusStyle(bg: p.failedBg, fg: p.failedFg, dot: true);
      case 'rejected':
        return _StatusStyle(bg: p.failedBg, fg: p.failedFg, dot: true);
      case 'cancelled':
        return _StatusStyle(bg: p.cancelledBg, fg: p.cancelledFg, dot: true);
      case 'urgent':
      case 'URGENT':
        return _StatusStyle(
          bg: p.urgentBg,
          fg: p.urgentFg,
          dot: false,
          allCaps: true,
        );
      default:
        return _StatusStyle(bg: p.cancelledBg, fg: p.cancelledFg, dot: true);
    }
  }
}

/// Filled red-orange URGENT pill used alongside StatusChip on urgent requests.
class UrgentTag extends StatelessWidget {
  const UrgentTag({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return StatusChip(status: 'urgent', dense: dense);
  }
}
