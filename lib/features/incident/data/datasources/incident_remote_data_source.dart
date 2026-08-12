import '../../data/models/incident_report_model.dart';

/// Remote data source interface for incident API calls.
abstract class IncidentRemoteDataSource {
  Future<IncidentReportModel> createIncident(Map<String, dynamic> body);
  Future<IncidentEvidenceModel> attachEvidence(
      String incidentId, Map<String, dynamic> body);
  Future<Map<String, dynamic>> uploadEvidenceFile({
    required String tourId,
    required String path,
    required String filename,
  });
  Future<IncidentReportModel> handleMissingStudent(Map<String, dynamic> body);
  Future<List<Map<String, dynamic>>> getMissingStudentCandidates(String tourId);
  Future<Map<String, dynamic>> getMissingStudentContext(String tourId, String rosterStudentId);
  Future<Map<String, dynamic>> getMissingStudentSnapshot(String incidentId);
  Future<IncidentReportModel> getIncidentById(String incidentId);
  Future<List<IncidentReportModel>> getIncidentsByTour(String tourId,
      {String? status});
  Future<List<IncidentReportModel>> getMyIncidents();
  Future<List<IncidentReportModel>> getIncidentsByStudent(String studentId);
  Future<IncidentReportModel> resolveIncident(
    String incidentId, {
    required String resolutionNote,
  });
}
