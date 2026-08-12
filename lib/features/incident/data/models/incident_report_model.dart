import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident_report_model.freezed.dart';
part 'incident_report_model.g.dart';

/// JSON-serializable model for [IncidentReport] (data layer).
@freezed
class IncidentReportModel with _$IncidentReportModel {
  const factory IncidentReportModel({
    required String id,
    required String tourId,
    String? tourInstanceId,
    String? tourName,
    String? schoolName,
    required String reporterId,
    required String reporterRole,
    required String incidentType,
    required String severity,
    required String status,
    required String title,
    String? description,
    required String incidentTime,
    String? locationText,
    double? latitude,
    double? longitude,
    @Default([]) List<String> affectedStudentIds,
    String? lastCheckpointId,
    String? acknowledgedBy,
    String? acknowledgedAt,
    String? resolvedBy,
    String? resolvedAt,
    String? resolutionNote,
    @Default(false) bool offlineCreated,
    @Default([]) List<IncidentEvidenceModel> evidences,
    required String createdAt,
    required String updatedAt,
  }) = _IncidentReportModel;

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) =>
      _$IncidentReportModelFromJson(json);
}

/// JSON-serializable model for [IncidentEvidence] (data layer).
@freezed
class IncidentEvidenceModel with _$IncidentEvidenceModel {
  const factory IncidentEvidenceModel({
    required String id,
    required String incidentId,
    required String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
    required String uploadedBy,
    required String uploadedAt,
  }) = _IncidentEvidenceModel;

  factory IncidentEvidenceModel.fromJson(Map<String, dynamic> json) =>
      _$IncidentEvidenceModelFromJson(json);
}
