import 'package:go_router/go_router.dart';

import 'presentation/views/attach_evidence_screen.dart';
import 'presentation/views/create_incident_screen.dart';
import 'presentation/views/incident_detail_screen.dart';
import 'presentation/views/incident_list_screen.dart';
import 'presentation/views/missing_student_alert_screen.dart';

/// Route definitions for the incident feature (Epic 17).
///
/// Register these routes in the app's root [GoRouter] configuration.
///
/// Routes:
/// - `/incident/list` — [IncidentListScreen] — tour incident list (Guide/Teacher)
/// - `/incident/create` — [CreateIncidentScreen] — report new incident (UC-INC-01)
/// - `/incident/missing` — [MissingStudentAlertScreen] — emergency UC-EMG-01
/// - `/incident/:id` — [IncidentDetailScreen]
/// - `/incident/:id/evidence` — TODO: AttachEvidenceScreen
/// - `/incident/child/:studentId` — TODO: ChildIncidentReportScreen (UC-PAR-09)
final incidentRoutes = [
  GoRoute(
    path: '/incident/list',
    builder: (context, state) {
      final tourId = state.uri.queryParameters['tourId'] ?? '';
      final readOnly = _isTruthyQueryParam(state.uri.queryParameters['readOnly']) ||
          _isTruthyQueryParam(state.uri.queryParameters['tourCompleted']);
      return IncidentListScreen(tourId: tourId, readOnly: readOnly);
    },
  ),
  GoRoute(
    path: '/incident/create',
    builder: (context, state) {
      final tourId = state.uri.queryParameters['tourId'] ?? '';
      final reporterRole = state.uri.queryParameters['reporterRole'];
      final studentId = state.uri.queryParameters['studentId'] ?? '';
      return CreateIncidentScreen(
        tourId: tourId,
        reporterRole: reporterRole ?? 'TOUR_GUIDE',
        initialAffectedStudentIds: studentId.isEmpty ? const [] : [studentId],
      );
    },
  ),
  GoRoute(
    path: '/incident/missing',
    builder: (context, state) {
      final tourId = state.uri.queryParameters['tourId'] ?? '';
      return MissingStudentAlertScreen(tourId: tourId);
    },
  ),
  GoRoute(
    path: '/incident/:id',
    builder: (context, state) {
      final incidentId = state.pathParameters['id'] ?? '';
      final readOnly = _isTruthyQueryParam(state.uri.queryParameters['readOnly']) ||
          _isTruthyQueryParam(state.uri.queryParameters['tourCompleted']);
      return IncidentDetailScreen(incidentId: incidentId, readOnly: readOnly);
    },
  ),
  GoRoute(
    path: '/incident/:id/evidence',
    builder: (context, state) {
      final incidentId = state.pathParameters['id'] ?? '';
      final tourId = state.uri.queryParameters['tourId'] ?? '';
      return AttachEvidenceScreen(incidentId: incidentId, tourId: tourId);
    },
  ),
];

bool _isTruthyQueryParam(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'y';
}
