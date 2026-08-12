import '../entities/incident_report.dart';
import '../entities/incident_severity.dart';
import '../entities/incident_status.dart';
import '../entities/incident_type.dart';

/// Abstract repository interface for incident operations (Clean Architecture).
///
/// The data layer ([IncidentRepositoryImpl]) provides the concrete implementation.
abstract class IncidentRepository {
  /// Create a new incident report (UC-INC-01, UC-GUI-03).
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
  });

  /// Attach evidence to an existing incident (UC-INC-02).
  Future<IncidentEvidence> attachEvidence({
    required String incidentId,
    required String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
  });

  Future<({String documentMetadataId, String fileUrl})> uploadEvidenceFile({
    required String tourId,
    required String path,
    required String filename,
  });

  /// Handle missing student emergency (UC-EMG-01).
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
  });

  Future<List<Map<String, dynamic>>> getMissingStudentCandidates(String tourId);
  Future<Map<String, dynamic>> getMissingStudentContext(String tourId, String rosterStudentId);
  Future<Map<String, dynamic>> getMissingStudentSnapshot(String incidentId);

  /// Get detailed incident by ID.
  Future<IncidentReport> getIncidentById(String incidentId);

  /// List incidents for a tour.
  Future<List<IncidentReport>> getIncidentsByTour(
    String tourId, {
    IncidentStatus? statusFilter,
  });

  /// List incidents reported by the current user (self-view).
  Future<List<IncidentReport>> getMyIncidents();

  /// List incidents involving a specific student (UC-PAR-09 — parent view).
  Future<List<IncidentReport>> getIncidentsByStudent(String studentId);

  /// Field resolve (Guide/Teacher). Note required.
  Future<IncidentReport> resolveIncident({
    required String incidentId,
    required String resolutionNote,
  });
}
