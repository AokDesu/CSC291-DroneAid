// Report — user-filed complaint against a Request after the package has
// reached `delivered` (or terminal `confirmed` / `failed`). Mirrors the
// shape written by functions/src/callable/reportDeliveryIssue.ts and
// transitioned by resolveReport.ts / dismissReport.ts. See
// docs/adr/0004-reports-as-first-class-dispute-entity.md.

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus { open, resolved, dismissed }

enum ReportResolution { confirmWithRemedy, failDelivery }

extension ReportStatusParse on ReportStatus {
  static ReportStatus parse(String? raw) {
    switch (raw) {
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.open;
    }
  }

  String get wire {
    switch (this) {
      case ReportStatus.open:
        return 'open';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
    }
  }
}

extension ReportResolutionParse on ReportResolution {
  static ReportResolution? parse(String? raw) {
    switch (raw) {
      case 'confirm_with_remedy':
        return ReportResolution.confirmWithRemedy;
      case 'fail_delivery':
        return ReportResolution.failDelivery;
      default:
        return null;
    }
  }

  String get wire {
    switch (this) {
      case ReportResolution.confirmWithRemedy:
        return 'confirm_with_remedy';
      case ReportResolution.failDelivery:
        return 'fail_delivery';
    }
  }

  String get label {
    switch (this) {
      case ReportResolution.confirmWithRemedy:
        return 'Delivery accepted with remedy';
      case ReportResolution.failDelivery:
        return 'Delivery marked failed';
    }
  }
}

class Report {
  const Report({
    required this.id,
    required this.requestId,
    required this.uid,
    required this.message,
    required this.status,
    required this.createdAt,
    this.requestStatusAtFiling,
    this.flightId,
    this.resolution,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String requestId;
  final String uid;
  final String message;
  final ReportStatus status;
  final DateTime createdAt;
  final String? requestStatusAtFiling;
  final String? flightId;
  final ReportResolution? resolution;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  static Report fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    // Subcollection path is `requests/{reqId}/reports/{reportId}` — the
    // parent of the parent collection is the Request doc.
    final reqId = snap.reference.parent.parent?.id ?? '';
    return Report(
      id: snap.id,
      requestId: reqId,
      uid: (data['uid'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      status: ReportStatusParse.parse(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      requestStatusAtFiling: data['requestStatus'] as String?,
      flightId: data['flightId'] as String?,
      resolution: ReportResolutionParse.parse(data['resolution'] as String?),
      resolutionNote: data['resolutionNote'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
    );
  }
}
