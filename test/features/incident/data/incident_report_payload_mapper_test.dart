import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/incident/data/mappers/incident_report_payload_mapper.dart';
import 'package:ventourkid_mobile/features/incident/data/models/incident_report_model.dart';

void main() {
  test('normalizeIncidentReportPayload fills summary-only fields', () {
    final normalized = normalizeIncidentReportPayload({
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'tourId': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'incidentType': 'MEDICAL',
      'severity': 'HIGH',
      'status': 'OPEN',
      'title': 'Hoc sinh bi nga',
      'createdAt': '2026-07-16T09:31:05Z',
      'updatedAt': '2026-07-16T09:31:05Z',
      'affectedStudentCount': 2,
    });

    final model = IncidentReportModel.fromJson(normalized);

    expect(model.reporterId, '');
    expect(model.reporterRole, 'TOUR_GUIDE');
    expect(model.incidentTime, '2026-07-16T09:31:05Z');
    expect(model.affectedStudentIds, isEmpty);
    expect(model.evidences, isEmpty);
  });
}
