import 'incident_severity.dart';
import 'incident_status.dart';
import 'incident_type.dart';

/// Domain entity representing an incident report (UC-INC-01, Epic 17).
///
/// This is a pure domain object — no JSON/serialization logic here.
/// Use [IncidentReportModel] in the data layer for serialization.
class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.tourId,
    this.tourInstanceId,
    this.tourName,
    this.schoolName,
    required this.reporterId,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.title,
    this.description,
    required this.incidentTime,
    this.locationText,
    this.latitude,
    this.longitude,
    this.affectedStudentIds = const [],
    this.lastCheckpointId,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    this.offlineCreated = false,
    this.evidences = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tourId;
  final String? tourInstanceId;
  final String? tourName;
  final String? schoolName;
  final String reporterId;
  final IncidentType incidentType;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final String title;
  final String? description;
  final DateTime incidentTime;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final List<String> affectedStudentIds;
  final String? lastCheckpointId;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final bool offlineCreated;
  final List<IncidentEvidence> evidences;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Domain entity for a single piece of evidence (UC-INC-02).
class IncidentEvidence {
  const IncidentEvidence({
    required this.id,
    required this.incidentId,
    required this.evidenceType,
    this.fileUrl,
    this.noteContent,
    this.description,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  final String id;
  final String incidentId;
  final String evidenceType;
  final String? fileUrl;
  final String? noteContent;
  final String? description;
  final String uploadedBy;
  final DateTime uploadedAt;
}
