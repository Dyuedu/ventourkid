import '../../../../core/error/app_failure.dart';
import '../../domain/entities/incident_report.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/repositories/incident_repository.dart';
import '../datasources/incident_remote_data_source.dart';
import '../models/incident_report_model.dart';
import 'package:dio/dio.dart';

/// Concrete implementation of [IncidentRepository] (data layer).
///
/// Maps between domain entities and data models.
/// Network exceptions are converted to [AppFailure] for clean error handling.
class IncidentRepositoryImpl implements IncidentRepository {
  IncidentRepositoryImpl(this._remoteDataSource);

  final IncidentRemoteDataSource _remoteDataSource;

  @override
  Future<IncidentReport> createIncident({
    required String tourId,
    String? tourInstanceId,
    required String reporterRole,
    required IncidentType incidentType,
    required IncidentSeverity severity,
    required String title,
    String? description,
    required DateTime incidentTime,
    String? locationText,
    double? latitude,
    double? longitude,
    List<String>? affectedStudentIds,
    bool offlineCreated = false,
    List<Map<String, dynamic>>? evidences,
  }) async {
    try {
      final model = await _remoteDataSource.createIncident({
        'tourId': tourId,
        if (tourInstanceId != null) 'tourInstanceId': tourInstanceId,
        'reporterRole': reporterRole,
        'incidentType': incidentType.toJson(),
        'severity': severity.toJson(),
        'title': title,
        if (description != null) 'description': description,
        'incidentTime': incidentTime.toUtc().toIso8601String(),
        if (locationText != null) 'locationText': locationText,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (affectedStudentIds != null)
          'affectedStudentIds': affectedStudentIds,
        'offlineCreated': offlineCreated,
        if (evidences != null && evidences.isNotEmpty) 'evidences': evidences,
      });
      return _toDomain(model);
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể tạo báo cáo sự cố');
    }
  }

  @override
  Future<IncidentEvidence> attachEvidence({
    required String incidentId,
    required String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
  }) async {
    try {
      final model = await _remoteDataSource.attachEvidence(incidentId, {
        'evidenceType': evidenceType,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (noteContent != null) 'noteContent': noteContent,
        if (description != null) 'description': description,
      });
      return _toEvidenceDomain(model);
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể đính kèm bằng chứng');
    }
  }

  @override
  Future<({String documentMetadataId, String fileUrl})> uploadEvidenceFile({
    required String tourId,
    required String path,
    required String filename,
  }) async {
    try {
      final data = await _remoteDataSource.uploadEvidenceFile(
        tourId: tourId,
        path: path,
        filename: filename,
      );
      return (
        documentMetadataId: data['documentMetadataId']?.toString() ?? '',
        fileUrl: data['fileUrl']?.toString() ?? '',
      );
    } on DioException catch (e) {
      throw AppFailure(
          e.response?.data?['message'] ?? 'Không thể tải ảnh bằng chứng lên');
    }
  }

  @override
  Future<IncidentReport> handleMissingStudent({
    required String tourId,
    required String missingStudentId,
    String? lastSeenDescription,
    double? reporterLatitude,
    double? reporterLongitude,
    String? trackerType,
    String? vehicleId,
    String? studentDeviceId,
    String? lastCheckpointId,
    bool offlineCreated = false,
  }) async {
    try {
      final model = await _remoteDataSource.handleMissingStudent({
        'tourId': tourId,
        'missingStudentId': missingStudentId,
        if (lastSeenDescription != null)
          'lastSeenDescription': lastSeenDescription,
        if (reporterLatitude != null) 'reporterLatitude': reporterLatitude,
        if (reporterLongitude != null) 'reporterLongitude': reporterLongitude,
        if (trackerType != null) 'trackerType': trackerType,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (studentDeviceId != null) 'studentDeviceId': studentDeviceId,
        if (lastCheckpointId != null) 'lastCheckpointId': lastCheckpointId,
        'offlineCreated': offlineCreated,
      });
      return _toDomain(model);
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể gửi cảnh báo mất học sinh');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMissingStudentCandidates(String tourId) =>
      _remoteDataSource.getMissingStudentCandidates(tourId);

  @override
  Future<Map<String, dynamic>> getMissingStudentContext(String tourId, String rosterStudentId) =>
      _remoteDataSource.getMissingStudentContext(tourId, rosterStudentId);

  @override
  Future<Map<String, dynamic>> getMissingStudentSnapshot(String incidentId) =>
      _remoteDataSource.getMissingStudentSnapshot(incidentId);

  @override
  Future<IncidentReport> getIncidentById(String incidentId) async {
    try {
      final model = await _remoteDataSource.getIncidentById(incidentId);
      return _toDomain(model);
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể tải sự cố');
    }
  }

  @override
  Future<List<IncidentReport>> getIncidentsByTour(
    String tourId, {
    IncidentStatus? statusFilter,
  }) async {
    try {
      final models = await _remoteDataSource.getIncidentsByTour(
        tourId,
        status: statusFilter?.toJson(),
      );
      return models.map(_toDomain).toList();
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể tải danh sách sự cố');
    }
  }

  @override
  Future<List<IncidentReport>> getMyIncidents() async {
    try {
      final models = await _remoteDataSource.getMyIncidents();
      return models.map(_toDomain).toList();
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể tải sự cố của bạn');
    }
  }

  @override
  Future<IncidentReport> resolveIncident({
    required String incidentId,
    required String resolutionNote,
  }) async {
    try {
      final model = await _remoteDataSource.resolveIncident(
        incidentId,
        resolutionNote: resolutionNote,
      );
      return _toDomain(model);
    } on DioException catch (e) {
      throw AppFailure(
          e.response?.data?['message'] ?? 'Không thể giải quyết sự cố');
    }
  }

  @override
  Future<List<IncidentReport>> getIncidentsByStudent(String studentId) async {
    try {
      final models =
          await _remoteDataSource.getIncidentsByStudent(studentId);
      return models.map(_toDomain).toList();
    } on DioException catch (e) {
      throw AppFailure(e.response?.data?['message'] ?? 'Không thể tải sự cố của học sinh');
    }
  }

  // ─── Mapping helpers ──────────────────────────────────────────────────────

  IncidentReport _toDomain(IncidentReportModel m) => IncidentReport(
        id: m.id,
        tourId: m.tourId,
        tourInstanceId: m.tourInstanceId,
        tourName: m.tourName,
        schoolName: m.schoolName,
        reporterId: m.reporterId,
        incidentType: IncidentType.fromJson(m.incidentType),
        severity: IncidentSeverity.fromJson(m.severity),
        status: IncidentStatus.fromJson(m.status),
        title: m.title,
        description: m.description,
        incidentTime: DateTime.parse(m.incidentTime),
        locationText: m.locationText,
        latitude: m.latitude,
        longitude: m.longitude,
        affectedStudentIds: m.affectedStudentIds,
        lastCheckpointId: m.lastCheckpointId,
        acknowledgedBy: m.acknowledgedBy,
        acknowledgedAt:
            m.acknowledgedAt != null ? DateTime.parse(m.acknowledgedAt!) : null,
        resolvedBy: m.resolvedBy,
        resolvedAt:
            m.resolvedAt != null ? DateTime.parse(m.resolvedAt!) : null,
        resolutionNote: m.resolutionNote,
        offlineCreated: m.offlineCreated,
        evidences: m.evidences.map(_toEvidenceDomain).toList(),
        createdAt: DateTime.parse(m.createdAt),
        updatedAt: DateTime.parse(m.updatedAt),
      );

  IncidentEvidence _toEvidenceDomain(IncidentEvidenceModel m) => IncidentEvidence(
        id: m.id,
        incidentId: m.incidentId,
        evidenceType: m.evidenceType,
        fileUrl: m.fileUrl,
        noteContent: m.noteContent,
        description: m.description,
        uploadedBy: m.uploadedBy,
        uploadedAt: DateTime.parse(m.uploadedAt),
      );
}
