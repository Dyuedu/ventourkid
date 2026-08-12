/// Normalizes incident API payloads before JSON deserialization.
///
/// List endpoints return summary payloads that omit detail-only fields such
/// as `reporterId` and `evidences`. Mobile uses one model for both summary
/// and detail views, so missing fields get safe defaults here.
Map<String, dynamic> normalizeIncidentReportPayload(Map<String, dynamic> raw) {
  final payload = Map<String, dynamic>.from(raw);
  final fallbackTimestamp = DateTime.now().toUtc().toIso8601String();

  payload.putIfAbsent('reporterId', () => '');
  payload.putIfAbsent('reporterRole', () => 'TOUR_GUIDE');
  payload.putIfAbsent(
    'incidentTime',
    () => payload['createdAt'] ?? fallbackTimestamp,
  );
  payload.putIfAbsent('createdAt', () => fallbackTimestamp);
  payload.putIfAbsent(
    'updatedAt',
    () => payload['createdAt'] ?? fallbackTimestamp,
  );
  payload.putIfAbsent('affectedStudentIds', () => const <dynamic>[]);
  payload.putIfAbsent('evidences', () => const <dynamic>[]);

  return payload;
}
