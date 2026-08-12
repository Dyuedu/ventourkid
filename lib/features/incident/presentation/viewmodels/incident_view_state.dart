import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/incident_report.dart';
import '../../domain/entities/incident_status.dart';

part 'incident_view_state.freezed.dart';

/// Represents the UI state for the incident feature screens.
@freezed
class IncidentViewState with _$IncidentViewState {
  const factory IncidentViewState({
    // ── List state ──────────────────────────────────────────────────────────
    @Default([]) List<IncidentReport> incidents,
    @Default(false) bool isLoadingList,

    // ── Detail state ─────────────────────────────────────────────────────────
    IncidentReport? selectedIncident,
    @Default(false) bool isLoadingDetail,

    // ── Create / Submit state ─────────────────────────────────────────────────
    @Default(false) bool isSubmitting,
    @Default(false) bool submitSuccess,

    // ── Evidence upload ──────────────────────────────────────────────────────
    @Default(false) bool isUploadingEvidence,

    // ── Missing student emergency ─────────────────────────────────────────────
    @Default(false) bool isMissingStudentAlertSent,

    // ── Shared error ─────────────────────────────────────────────────────────
    String? errorMessage,

    // ── Active filter ────────────────────────────────────────────────────────
    IncidentStatus? activeStatusFilter,
  }) = _IncidentViewState;
}
