import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/repositories/incident_repository.dart';
import 'incident_view_state.dart';

/// ViewModel for all incident-related screens.
///
/// Manages list, detail, creation (UC-INC-01/UC-GUI-03), evidence upload
/// (UC-INC-02), and missing student emergency (UC-EMG-01).
class IncidentViewModel extends StateNotifier<IncidentViewState> {
  IncidentViewModel(this._repository) : super(const IncidentViewState());

  final IncidentRepository _repository;

  // ─── List Operations ─────────────────────────────────────────────────────

  /// Load all incidents for a tour, respecting active status filter.
  Future<void> loadIncidentsByTour(
    String tourId, {
    IncidentStatus? statusFilter,
  }) async {
    state = state.copyWith(isLoadingList: true, errorMessage: null);
    try {
      final incidents = await _repository.getIncidentsByTour(
        tourId,
        statusFilter: statusFilter ?? state.activeStatusFilter,
      );
      state = state.copyWith(incidents: incidents, isLoadingList: false);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoadingList: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
          isLoadingList: false, errorMessage: 'Lỗi không xác định: $e');
    }
  }

  /// Load incidents reported by the authenticated field actor (self-view).
  Future<void> loadMyIncidents() async {
    state = state.copyWith(isLoadingList: true, errorMessage: null);
    try {
      final incidents = await _repository.getMyIncidents();
      state = state.copyWith(incidents: incidents, isLoadingList: false);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoadingList: false, errorMessage: e.message);
    }
  }

  /// Load incidents involving a specific student (UC-PAR-09 parent view).
  Future<void> loadIncidentsByStudent(String studentId) async {
    state = state.copyWith(isLoadingList: true, errorMessage: null);
    try {
      final incidents = await _repository.getIncidentsByStudent(studentId);
      state = state.copyWith(incidents: incidents, isLoadingList: false);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoadingList: false, errorMessage: e.message);
    }
  }

  void setStatusFilter(IncidentStatus? filter) {
    state = state.copyWith(activeStatusFilter: filter);
  }

  // ─── Detail ──────────────────────────────────────────────────────────────

  Future<void> loadIncidentDetail(String incidentId) async {
    state = state.copyWith(isLoadingDetail: true, errorMessage: null);
    try {
      final incident = await _repository.getIncidentById(incidentId);
      state =
          state.copyWith(selectedIncident: incident, isLoadingDetail: false);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoadingDetail: false, errorMessage: e.message);
    }
  }

  // ─── Create Incident (UC-INC-01, UC-GUI-03) ───────────────────────────────

  Future<bool> createIncident({
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
    state = state.copyWith(isSubmitting: true, submitSuccess: false, errorMessage: null);
    try {
      final created = await _repository.createIncident(
        tourId: tourId,
        tourInstanceId: tourInstanceId,
        reporterRole: reporterRole,
        incidentType: incidentType,
        severity: severity,
        title: title,
        description: description,
        incidentTime: incidentTime,
        locationText: locationText,
        latitude: latitude,
        longitude: longitude,
        affectedStudentIds: affectedStudentIds,
        offlineCreated: offlineCreated,
        evidences: evidences,
      );
      // Prepend to list so it appears at the top.
      state = state.copyWith(
        isSubmitting: false,
        submitSuccess: true,
        selectedIncident: created,
        incidents: [created, ...state.incidents],
      );
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  // ─── Attach Evidence (UC-INC-02) ─────────────────────────────────────────

  Future<bool> attachEvidence({
    required String incidentId,
    required String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
  }) async {
    state = state.copyWith(isUploadingEvidence: true, errorMessage: null);
    try {
      await _repository.attachEvidence(
        incidentId: incidentId,
        evidenceType: evidenceType,
        fileUrl: fileUrl,
        noteContent: noteContent,
        description: description,
      );
      // Reload detail to reflect new evidence.
      await loadIncidentDetail(incidentId);
      state = state.copyWith(isUploadingEvidence: false);
      return true;
    } on AppFailure catch (e) {
      state =
          state.copyWith(isUploadingEvidence: false, errorMessage: e.message);
      return false;
    }
  }

  // ─── Missing Student Emergency (UC-EMG-01) ────────────────────────────────

  Future<bool> handleMissingStudent({
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
    state = state.copyWith(
        isSubmitting: true,
        isMissingStudentAlertSent: false,
        errorMessage: null);
    try {
      final incident = await _repository.handleMissingStudent(
        tourId: tourId,
        missingStudentId: missingStudentId,
        lastSeenDescription: lastSeenDescription,
        reporterLatitude: reporterLatitude,
        reporterLongitude: reporterLongitude,
        trackerType: trackerType,
        vehicleId: vehicleId,
        studentDeviceId: studentDeviceId,
        lastCheckpointId: lastCheckpointId,
        offlineCreated: offlineCreated,
      );
      state = state.copyWith(
        isSubmitting: false,
        isMissingStudentAlertSent: true,
        selectedIncident: incident,
        incidents: [incident, ...state.incidents],
      );
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  Future<bool> resolveIncident({
    required String incidentId,
    required String resolutionNote,
    String? tourId,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updated = await _repository.resolveIncident(
        incidentId: incidentId,
        resolutionNote: resolutionNote,
      );
      final incidents = state.incidents
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      state = state.copyWith(
        isSubmitting: false,
        selectedIncident: updated,
        incidents: incidents,
      );
      if (tourId != null && tourId.isNotEmpty) {
        await loadIncidentsByTour(tourId);
      }
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void resetSubmitState() {
    state = state.copyWith(submitSuccess: false, isMissingStudentAlertSent: false);
  }
}
