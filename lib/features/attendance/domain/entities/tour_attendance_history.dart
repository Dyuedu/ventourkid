class TourAttendanceHistory {
  const TourAttendanceHistory({
    required this.tourId,
    required this.tourName,
    required this.status,
    required this.rosterCount,
    required this.activities,
    this.tourDate,
    this.schoolId,
    this.schoolName,
  });

  final String tourId;
  final String tourName;
  final String status;
  final DateTime? tourDate;
  final String? schoolId;
  final String? schoolName;
  final int rosterCount;
  final List<TourAttendanceActivityHistory> activities;

  factory TourAttendanceHistory.fromJson(Map<String, dynamic> json) {
    return TourAttendanceHistory(
      tourId: json['tourId']?.toString() ?? '',
      tourName: json['tourName']?.toString() ?? 'Tour',
      status: json['status']?.toString() ?? 'UNKNOWN',
      tourDate: _parseDate(json['tourDate']),
      schoolId: json['schoolId']?.toString(),
      schoolName: json['schoolName']?.toString(),
      rosterCount: int.tryParse(json['rosterCount']?.toString() ?? '') ?? 0,
      activities: _mapList(
        json['activities'],
        TourAttendanceActivityHistory.fromJson,
      ),
    );
  }

  TourAttendanceHistory scopedToPlanItem(String? planItemId) {
    final matches = activities
        .where((activity) => samePlanItemId(activity.planItemId, planItemId))
        .toList();
    if (matches.length == activities.length) return this;
    return TourAttendanceHistory(
      tourId: tourId,
      tourName: tourName,
      status: status,
      tourDate: tourDate,
      schoolId: schoolId,
      schoolName: schoolName,
      rosterCount: rosterCount,
      activities: matches,
    );
  }
}

class TourAttendanceActivityHistory {
  const TourAttendanceActivityHistory({
    required this.planItemId,
    required this.students,
    required this.summary,
    this.checkpointId,
    this.title,
    this.activityName,
    this.destinationName,
    this.checkpointName,
    this.checkpointKind,
    this.itemKind,
    this.legType,
    this.plannedStart,
    this.plannedEnd,
    this.operationVehicleId,
    this.vehicleLabel,
    this.sessions = const [],
  });

  final String planItemId;
  final String? checkpointId;
  final String? title;
  final String? activityName;
  final String? destinationName;
  final String? checkpointName;
  final String? checkpointKind;
  final String? itemKind;
  final String? legType;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final String? operationVehicleId;
  final String? vehicleLabel;
  final Map<String, int> summary;
  final List<TourAttendanceSessionHistory> sessions;
  final List<TourAttendanceStudentHistory> students;

  String get displayTitle {
    final value = title?.trim();
    if (value != null && value.isNotEmpty) return value;
    final activity = activityName?.trim();
    if (activity != null && activity.isNotEmpty) return activity;
    final checkpoint = checkpointName?.trim();
    if (checkpoint != null && checkpoint.isNotEmpty) return checkpoint;
    return 'Hoạt động điểm danh';
  }

  int countOf(String key) => summary[key] ?? summary[key.toUpperCase()] ?? 0;

  factory TourAttendanceActivityHistory.fromJson(Map<String, dynamic> json) {
    return TourAttendanceActivityHistory(
      planItemId: json['planItemId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString(),
      title: json['title']?.toString(),
      activityName: json['activityName']?.toString(),
      destinationName: json['destinationName']?.toString(),
      checkpointName: json['checkpointName']?.toString(),
      checkpointKind: json['checkpointKind']?.toString(),
      itemKind: json['itemKind']?.toString(),
      legType: json['legType']?.toString(),
      plannedStart: _parseDate(json['plannedStart']),
      plannedEnd: _parseDate(json['plannedEnd']),
      operationVehicleId: json['operationVehicleId']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
      summary: _intMap(json['summary']),
      sessions: _mapList(json['sessions'], TourAttendanceSessionHistory.fromJson),
      students: _mapList(json['students'], TourAttendanceStudentHistory.fromJson),
    );
  }
}

bool samePlanItemId(String? left, String? right) {
  final a = (left ?? '').trim().toLowerCase();
  final b = (right ?? '').trim().toLowerCase();
  return a.isNotEmpty && a == b;
}

class TourAttendanceSessionHistory {
  const TourAttendanceSessionHistory({
    required this.sessionId,
    required this.status,
    this.sessionName,
    this.sessionType,
    this.startedAt,
    this.closedAt,
    this.startedByName,
  });

  final String sessionId;
  final String? sessionName;
  final String? sessionType;
  final String status;
  final DateTime? startedAt;
  final DateTime? closedAt;
  final String? startedByName;

  factory TourAttendanceSessionHistory.fromJson(Map<String, dynamic> json) {
    return TourAttendanceSessionHistory(
      sessionId: json['sessionId']?.toString() ?? '',
      sessionName: json['sessionName']?.toString(),
      sessionType: json['sessionType']?.toString(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      startedAt: _parseDate(json['startedAt']),
      closedAt: _parseDate(json['closedAt']),
      startedByName: json['startedByName']?.toString(),
    );
  }
}

class TourAttendanceStudentHistory {
  const TourAttendanceStudentHistory({
    required this.rosterStudentId,
    required this.fullName,
    required this.status,
    this.studentCode,
    this.className,
    this.gender,
    this.operationVehicleId,
    this.vehicleLabel,
    this.method,
    this.confidence,
    this.recordedAt,
    this.markedByAccountId,
    this.markedByName,
    this.overrideReason,
    this.overriddenAt,
    this.sessionId,
    this.sessionName,
  });

  final String rosterStudentId;
  final String? studentCode;
  final String fullName;
  final String? className;
  final String? gender;
  final String? operationVehicleId;
  final String? vehicleLabel;
  final String status;
  final String? method;
  final double? confidence;
  final DateTime? recordedAt;
  final String? markedByAccountId;
  final String? markedByName;
  final String? overrideReason;
  final DateTime? overriddenAt;
  final String? sessionId;
  final String? sessionName;

  String get normalizedStatus {
    final value = status.toUpperCase();
    return value == 'LATE' ? 'ABSENT' : value;
  }

  factory TourAttendanceStudentHistory.fromJson(Map<String, dynamic> json) {
    return TourAttendanceStudentHistory(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      studentCode: json['studentCode']?.toString(),
      fullName: json['fullName']?.toString() ?? 'Học sinh',
      className: json['className']?.toString(),
      gender: json['gender']?.toString(),
      operationVehicleId: json['operationVehicleId']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      method: json['method']?.toString(),
      confidence: double.tryParse(json['confidence']?.toString() ?? ''),
      recordedAt: _parseDate(json['recordedAt']),
      markedByAccountId: json['markedByAccountId']?.toString(),
      markedByName: json['markedByName']?.toString(),
      overrideReason: json['overrideReason']?.toString(),
      overriddenAt: _parseDate(json['overriddenAt']),
      sessionId: json['sessionId']?.toString(),
      sessionName: json['sessionName']?.toString(),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(
      key.toString(),
      int.tryParse(item?.toString() ?? '') ?? 0,
    ),
  );
}

List<T> _mapList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) mapper,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList();
}
