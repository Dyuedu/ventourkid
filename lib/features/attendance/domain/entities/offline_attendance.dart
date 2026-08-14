class AttendanceTour {
  const AttendanceTour({
    required this.tourId,
    required this.tourName,
    required this.status,
    required this.rosterCount,
    this.tourDate,
    this.schoolId,
    this.schoolName,
    this.bookingStatus,
    this.operationPlanStatus,
    this.closingChecklistStatus,
    this.completedAt,
  });

  final String tourId;
  final String tourName;
  /// Display-oriented status from API (plan/closing preferred over booking).
  final String status;
  final DateTime? tourDate;
  final String? schoolId;
  final String? schoolName;
  final int rosterCount;
  final String? bookingStatus;
  final String? operationPlanStatus;
  final String? closingChecklistStatus;
  final DateTime? completedAt;

  bool get isCompleted {
    final plan = (operationPlanStatus ?? status).toUpperCase();
    final closing = (closingChecklistStatus ?? '').toUpperCase();
    return plan == 'COMPLETED' || closing == 'COMPLETED' || status.toUpperCase() == 'COMPLETED';
  }

  bool get isReadyToComplete =>
      (closingChecklistStatus ?? status).toUpperCase() == 'READY_TO_COMPLETE';

  /// True when the tour is still before run day — view plan only, no ATT-006 ops.
  ///
  /// Prefer [tourDate] > today. Also treats READY + future date the same way.
  /// IN_PROGRESS / ONGOING stay executable even if dates are noisy.
  bool get isUpcomingPrepOnly {
    final plan = (operationPlanStatus ?? status).toUpperCase();
    if (plan == 'IN_PROGRESS' ||
        plan == 'ONGOING' ||
        status.toUpperCase() == 'ONGOING') {
      return false;
    }
    final date = tourDate;
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.isAfter(today);
  }

  /// Legacy 24h active-tab grace (COMPLETED now goes to history immediately).
  static const activeCompletedGrace = Duration(hours: 24);

  /// History retention hint (matches API history window default).
  static const historyRetention = Duration(days: 30);

  /// Remaining time on “Đang chạy” after complete; null if not applicable.
  Duration? get activeGraceRemaining {
    if (!isCompleted || completedAt == null) return null;
    final left = completedAt!.add(activeCompletedGrace).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Vietnamese label for the completed grace countdown on the active tab.
  String get activeGraceLabelVi {
    final left = activeGraceRemaining;
    if (left == null) {
      return 'Tour đã hoàn tất · còn hiển thị trong 24 giờ';
    }
    if (left <= Duration.zero) {
      return 'Tour đã hoàn tất · sắp ẩn khỏi tab Đang chạy';
    }
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60);
    if (hours > 0) {
      return 'Tour đã hoàn tất · còn hiển thị $hours giờ $minutes phút';
    }
    if (minutes > 0) {
      return 'Tour đã hoàn tất · còn hiển thị $minutes phút';
    }
    return 'Tour đã hoàn tất · còn hiển thị dưới 1 phút';
  }

  /// Vietnamese label for history retention (30 days).
  String get historyRetentionLabelVi {
    if (completedAt == null) {
      return 'Tour đã hoàn tất · xem lại trong 30 ngày';
    }
    final left =
        completedAt!.add(historyRetention).difference(DateTime.now());
    if (left.isNegative || left <= Duration.zero) {
      return 'Tour đã hoàn tất · sắp hết hạn xem lại';
    }
    final days = left.inDays;
    if (days > 0) {
      return 'Tour đã hoàn tất · còn xem lại $days ngày';
    }
    final hours = left.inHours;
    if (hours > 0) {
      return 'Tour đã hoàn tất · còn xem lại $hours giờ';
    }
    return 'Tour đã hoàn tất · còn xem lại dưới 1 giờ';
  }

  /// Vietnamese label for HDV/GV dashboard chips.
  String get statusLabelVi {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Đã hoàn tất';
      case 'READY_TO_COMPLETE':
        return 'Sẵn sàng đóng';
      case 'IN_PROGRESS':
      case 'ONGOING':
        return 'Đang vận hành';
      case 'READY':
        return 'Sẵn sàng';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'PLANNING':
      case 'DRAFT':
        return 'Đang lập kế hoạch';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  /// Nhãn tiếng Việt cho chip trạng thái; giữ nguyên mã lạ để còn debug được.
  String get statusLabel => switch (status.toUpperCase()) {
    'PENDING_PLANNING' => 'Chờ lập kế hoạch',
    'PLANNING' => 'Đang lập kế hoạch',
    'IN_REVIEW' => 'Chờ duyệt',
    'APPROVED' => 'Đã duyệt',
    'READY' => 'Sẵn sàng khởi hành',
    'IN_PROGRESS' => 'Đang diễn ra',
    'COMPLETED' => 'Đã hoàn thành',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };

  factory AttendanceTour.fromJson(Map<String, dynamic> json) {
    return AttendanceTour(
      tourId: json['tourId']?.toString() ?? '',
      tourName: json['tourName']?.toString() ?? 'Tour',
      status: json['status']?.toString() ?? 'UNKNOWN',
      tourDate: _parseDate(json['tourDate']),
      schoolId: json['schoolId']?.toString(),
      schoolName: json['schoolName']?.toString(),
      rosterCount: int.tryParse(json['rosterCount']?.toString() ?? '') ?? 0,
      bookingStatus: json['bookingStatus']?.toString(),
      operationPlanStatus: json['operationPlanStatus']?.toString(),
      closingChecklistStatus: json['closingChecklistStatus']?.toString(),
      completedAt: _parseDate(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourId': tourId,
      'tourName': tourName,
      'status': status,
      'tourDate': tourDate?.toIso8601String(),
      'schoolId': schoolId,
      'schoolName': schoolName,
      'rosterCount': rosterCount,
      'bookingStatus': bookingStatus,
      'operationPlanStatus': operationPlanStatus,
      'closingChecklistStatus': closingChecklistStatus,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

class AttendanceCheckpoint {
  const AttendanceCheckpoint({
    required this.planItemId,
    required this.checkpointId,
    required this.name,
    required this.sortOrder,
    required this.kind,
    this.plannedStart,
    this.plannedEnd,
  });

  final String planItemId;
  final String checkpointId;
  final String name;
  final int sortOrder;
  final String kind;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;

  factory AttendanceCheckpoint.fromJson(Map<String, dynamic> json) {
    return AttendanceCheckpoint(
      planItemId: json['planItemId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Checkpoint',
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      kind: json['kind']?.toString() ?? 'NORMAL',
      plannedStart: _parseDate(json['plannedStart']),
      plannedEnd: _parseDate(json['plannedEnd']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planItemId': planItemId,
      'checkpointId': checkpointId,
      'name': name,
      'sortOrder': sortOrder,
      'kind': kind,
      'plannedStart': plannedStart?.toIso8601String(),
      'plannedEnd': plannedEnd?.toIso8601String(),
    };
  }
}

class VehicleInspectionOtpResult {
  const VehicleInspectionOtpResult({
    required this.maskedDestination,
    this.cooldownSeconds = 59,
    this.deliveryChannel = 'EMAIL',
  });

  final String maskedDestination;
  final int cooldownSeconds;

  /// EMAIL or SMS — channel that actually delivered the OTP.
  final String deliveryChannel;

  bool get deliveredByEmail => deliveryChannel.toUpperCase() == 'EMAIL';

  factory VehicleInspectionOtpResult.fromJson(Map<String, dynamic> json) {
    final channel = json['deliveryChannel']?.toString().toUpperCase();
    return VehicleInspectionOtpResult(
      maskedDestination:
          json['maskedDestination']?.toString() ??
          json['maskedPhone']?.toString() ??
          'địa chỉ đã đăng ký',
      cooldownSeconds:
          int.tryParse(json['cooldownSeconds']?.toString() ?? '') ?? 59,
      deliveryChannel: channel == 'SMS' ? 'SMS' : 'EMAIL',
    );
  }
}

class VehicleInspectionConfirmResult {
  const VehicleInspectionConfirmResult({
    required this.confirmed,
    this.confirmedAt,
  });

  final bool confirmed;
  final DateTime? confirmedAt;

  factory VehicleInspectionConfirmResult.fromJson(Map<String, dynamic> json) {
    return VehicleInspectionConfirmResult(
      confirmed:
          json['confirmed'] == true ||
          json['confirmed']?.toString().toLowerCase() == 'true',
      confirmedAt: _parseDate(json['confirmedAt']),
    );
  }
}

class PreTripChecklist {
  const PreTripChecklist({
    required this.tourId,
    required this.confirmed,
    required this.items,
    this.confirmedAt,
    this.confirmedBy,
  });

  final String tourId;
  final bool confirmed;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final List<PreTripChecklistItem> items;

  bool get requiredItemsDone => items
      .where((item) => item.important)
      .every((item) => item.checked || item.status == 'NOT_APPLICABLE');

  PreTripChecklist copyWith({
    bool? confirmed,
    DateTime? confirmedAt,
    String? confirmedBy,
    List<PreTripChecklistItem>? items,
  }) {
    return PreTripChecklist(
      tourId: tourId,
      confirmed: confirmed ?? this.confirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      items: items ?? this.items,
    );
  }

  factory PreTripChecklist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PreTripChecklist(
      tourId: json['tourId']?.toString() ?? '',
      confirmed:
          json['confirmed'] == true ||
          json['confirmed']?.toString().toLowerCase() == 'true',
      confirmedAt: _parseDate(json['confirmedAt']),
      confirmedBy: json['confirmedBy']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(PreTripChecklistItem.fromJson)
                .toList()
          : const <PreTripChecklistItem>[],
    );
  }
}

class PreTripChecklistItem {
  const PreTripChecklistItem({
    required this.id,
    required this.title,
    required this.checked,
    required this.important,
    required this.status,
    this.description,
    this.note,
    this.category,
    this.quantity,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? note;
  final String? category;
  final int? quantity;
  final bool important;
  final String status;
  final bool checked;
  final DateTime? updatedAt;

  PreTripChecklistItem copyWith({bool? checked, String? note}) {
    return PreTripChecklistItem(
      id: id,
      title: title,
      description: description,
      note: note ?? this.note,
      category: category,
      quantity: quantity,
      important: important,
      status: checked == null
          ? status
          : checked
          ? 'DONE'
          : 'TODO',
      checked: checked ?? this.checked,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {'id': id, 'checked': checked, 'note': note};
  }

  factory PreTripChecklistItem.fromJson(Map<String, dynamic> json) {
    return PreTripChecklistItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Checklist',
      description: json['description']?.toString(),
      note: json['note']?.toString(),
      category: json['category']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? ''),
      important:
          json['important'] == true ||
          json['important']?.toString().toLowerCase() == 'true',
      status: json['status']?.toString() ?? 'TODO',
      checked:
          json['checked'] == true ||
          json['checked']?.toString().toLowerCase() == 'true',
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.rosterStudentId,
    required this.fullName,
    this.studentCode,
    this.dateOfBirth,
    this.gender,
    this.classId,
    this.className,
    this.operationVehicleId,
    this.vehicleLabel,
  });

  final String rosterStudentId;
  final String fullName;
  final String? studentCode;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? classId;
  final String? className;
  final String? operationVehicleId;
  /// Biển số / nhãn xe từ API (plate · externalLabel).
  final String? vehicleLabel;

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceStudent(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Học sinh',
      studentCode: json['studentCode']?.toString(),
      dateOfBirth: _parseDate(json['dateOfBirth']),
      gender: json['gender']?.toString(),
      classId: json['classId']?.toString(),
      className: json['className']?.toString(),
      operationVehicleId: json['operationVehicleId']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rosterStudentId': rosterStudentId,
      'fullName': fullName,
      'studentCode': studentCode,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'classId': classId,
      'className': className,
      'operationVehicleId': operationVehicleId,
      'vehicleLabel': vehicleLabel,
    };
  }
}

/// Sensitive field-only data. This is deliberately fetched on demand and is
/// never placed in the offline attendance cache.
class FieldFoodAllergyAlert {
  const FieldFoodAllergyAlert({
    required this.rosterStudentId,
    required this.fullName,
    required this.operationVehicleId,
    required this.vehicleLabel,
    required this.severity,
    required this.foodAllergies,
    this.className,
    this.dietaryRestrictions,
    this.emergencyNote,
  });

  final String rosterStudentId;
  final String fullName;
  final String operationVehicleId;
  final String vehicleLabel;
  final String severity;
  final String foodAllergies;
  final String? className;
  final String? dietaryRestrictions;
  final String? emergencyNote;

  factory FieldFoodAllergyAlert.fromJson(Map<String, dynamic> json) {
    return FieldFoodAllergyAlert(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Học sinh',
      operationVehicleId: json['operationVehicleId']?.toString() ?? '',
      vehicleLabel: json['vehicleLabel']?.toString() ?? 'Xe được phân công',
      severity: json['severity']?.toString().toUpperCase() ?? 'MEDIUM',
      foodAllergies: json['foodAllergies']?.toString() ?? '',
      className: json['className']?.toString(),
      dietaryRestrictions: json['dietaryRestrictions']?.toString(),
      emergencyNote: json['emergencyNote']?.toString(),
    );
  }
}

class AttendanceSessionDraft {
  const AttendanceSessionDraft({
    required this.sessionId,
    required this.planItemId,
    required this.tourId,
    required this.checkpointId,
    required this.operationVehicleId,
    required this.status,
    required this.studentCount,
    required this.startedAt,
    this.sessionName,
    this.sessionType,
    this.closedAt,
  });

  final String sessionId;
  final String planItemId;
  final String tourId;
  final String checkpointId;
  final String operationVehicleId;
  final String status;
  final int studentCount;
  final DateTime startedAt;
  final String? sessionName;
  final String? sessionType;
  final DateTime? closedAt;

  factory AttendanceSessionDraft.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDraft(
      sessionId: json['sessionId']?.toString() ?? '',
      planItemId: json['planItemId']?.toString() ?? '',
      tourId: json['tourId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString() ?? '',
      operationVehicleId: json['operationVehicleId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      studentCount: int.tryParse(json['studentCount']?.toString() ?? '') ?? 0,
      startedAt: _parseDate(json['startedAt']) ?? DateTime.now().toUtc(),
      sessionName: json['sessionName']?.toString(),
      sessionType: json['sessionType']?.toString(),
      closedAt: _parseDate(json['closedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'planItemId': planItemId,
      'tourId': tourId,
      'checkpointId': checkpointId,
      'operationVehicleId': operationVehicleId,
      'status': status,
      'studentCount': studentCount,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'sessionName': sessionName,
      'sessionType': sessionType,
      'closedAt': closedAt?.toUtc().toIso8601String(),
    };
  }
}

class AttendanceSessionSummary {
  const AttendanceSessionSummary({
    required this.sessionId,
    required this.checkpointId,
    required this.status,
    required this.summary,
    this.planItemId,
    this.sessionName,
    this.sessionType,
    this.startedAt,
    this.closedAt,
  });

  final String sessionId;
  final String checkpointId;
  final String? planItemId;
  final String status;
  final Map<String, int> summary;
  final String? sessionName;
  final String? sessionType;
  final DateTime? startedAt;
  final DateTime? closedAt;

  factory AttendanceSessionSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    return AttendanceSessionSummary(
      sessionId: json['sessionId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString() ?? '',
      planItemId: json['planItemId']?.toString().trim().isNotEmpty == true
          ? json['planItemId'].toString().trim()
          : null,
      status: json['status']?.toString() ?? 'OPEN',
      sessionName: json['sessionName']?.toString(),
      sessionType: json['sessionType']?.toString(),
      startedAt: _parseDate(json['startedAt']),
      closedAt: _parseDate(json['closedAt']),
      summary: summary is Map
          ? summary.map(
              (key, value) => MapEntry(
                key.toString(),
                int.tryParse(value?.toString() ?? '') ?? 0,
              ),
            )
          : const {},
    );
  }
}

class OfflineAttendanceMark {
  const OfflineAttendanceMark({
    required this.localId,
    required this.attendanceSessionId,
    required this.planItemId,
    required this.rosterStudentId,
    required this.finalStatus,
    required this.recordedAt,
    required this.reason,
    required this.studentName,
    required this.tourId,
    required this.checkpointId,
    this.syncResult,
  });

  final String localId;
  final String attendanceSessionId;
  final String planItemId;
  final String rosterStudentId;
  final String finalStatus;
  final DateTime recordedAt;
  final String reason;
  final String studentName;
  final String tourId;
  final String checkpointId;
  final String? syncResult;

  bool get isPendingSync => syncResult == null;

  String get syncKey => '$attendanceSessionId::$rosterStudentId';

  factory OfflineAttendanceMark.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceMark(
      localId: json['localId']?.toString() ?? '',
      attendanceSessionId: json['attendanceSessionId']?.toString() ?? '',
      planItemId: json['planItemId']?.toString() ?? '',
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      finalStatus: json['finalStatus']?.toString() ?? 'PRESENT',
      recordedAt: _parseDate(json['recordedAt']) ?? DateTime.now().toUtc(),
      reason: json['reason']?.toString() ?? 'Mobile offline attendance',
      studentName: json['studentName']?.toString() ?? 'Học sinh',
      tourId: json['tourId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString() ?? '',
      syncResult: json['syncResult']?.toString(),
    );
  }

  OfflineAttendanceMark copyWith({
    String? attendanceSessionId,
    String? syncResult,
  }) {
    return OfflineAttendanceMark(
      localId: localId,
      attendanceSessionId: attendanceSessionId ?? this.attendanceSessionId,
      planItemId: planItemId,
      rosterStudentId: rosterStudentId,
      finalStatus: finalStatus,
      recordedAt: recordedAt,
      reason: reason,
      studentName: studentName,
      tourId: tourId,
      checkpointId: checkpointId,
      syncResult: syncResult,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'attendanceSessionId': attendanceSessionId,
      'planItemId': planItemId,
      'rosterStudentId': rosterStudentId,
      'finalStatus': finalStatus,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
      'reason': reason,
      'studentName': studentName,
      'tourId': tourId,
      'checkpointId': checkpointId,
      'syncResult': syncResult,
    };
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'attendanceSessionId': attendanceSessionId,
      'planItemId': planItemId,
      'rosterStudentId': rosterStudentId,
      'finalStatus': finalStatus.toUpperCase() == 'LATE'
          ? 'ABSENT'
          : finalStatus,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
      'reason': reason,
    };
  }
}

class OfflineSyncCommand {
  const OfflineSyncCommand({
    required this.localId,
    required this.clientMutationId,
    required this.type,
    required this.clientCreatedAt,
    required this.payload,
    this.syncResult,
  });

  final String localId;
  final String clientMutationId;
  final String type;
  final DateTime clientCreatedAt;
  final Map<String, dynamic> payload;
  final String? syncResult;

  bool get isPendingSync => syncResult == null;

  String get syncKey => clientMutationId;

  factory OfflineSyncCommand.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return OfflineSyncCommand(
      localId: json['localId']?.toString() ?? '',
      clientMutationId: json['clientMutationId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      clientCreatedAt:
          _parseDate(json['clientCreatedAt']) ?? DateTime.now().toUtc(),
      payload: payload is Map<String, dynamic>
          ? payload
          : payload is Map
          ? Map<String, dynamic>.from(payload)
          : const {},
      syncResult: json['syncResult']?.toString(),
    );
  }

  OfflineSyncCommand copyWith({
    Map<String, dynamic>? payload,
    String? syncResult,
  }) {
    return OfflineSyncCommand(
      localId: localId,
      clientMutationId: clientMutationId,
      type: type,
      clientCreatedAt: clientCreatedAt,
      payload: payload ?? this.payload,
      syncResult: syncResult,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'clientMutationId': clientMutationId,
      'type': type,
      'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
      'payload': payload,
      'syncResult': syncResult,
    };
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'clientMutationId': clientMutationId,
      'type': type,
      'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }
}

class OfflineSyncSummary {
  const OfflineSyncSummary({
    required this.synced,
    required this.conflicts,
    required this.records,
    required this.commands,
  });

  final int synced;
  final int conflicts;
  final List<OfflineSyncRecordResult> records;
  final List<OfflineSyncCommandResult> commands;

  factory OfflineSyncSummary.empty() {
    return const OfflineSyncSummary(
      synced: 0,
      conflicts: 0,
      records: [],
      commands: [],
    );
  }

  factory OfflineSyncSummary.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    final commands = json['commands'];
    return OfflineSyncSummary(
      synced: int.tryParse(json['synced']?.toString() ?? '') ?? 0,
      conflicts: int.tryParse(json['conflicts']?.toString() ?? '') ?? 0,
      records: records is List
          ? records
                .whereType<Map<String, dynamic>>()
                .map(OfflineSyncRecordResult.fromJson)
                .toList()
          : const [],
      commands: commands is List
          ? commands
                .whereType<Map<String, dynamic>>()
                .map(OfflineSyncCommandResult.fromJson)
                .toList()
          : const [],
    );
  }
}

class OfflineSyncCommandResult {
  const OfflineSyncCommandResult({
    required this.clientMutationId,
    required this.type,
    required this.result,
    this.conflictCode,
  });

  final String clientMutationId;
  final String type;
  final String result;
  final String? conflictCode;

  String get syncKey => clientMutationId;

  factory OfflineSyncCommandResult.fromJson(Map<String, dynamic> json) {
    return OfflineSyncCommandResult(
      clientMutationId: json['clientMutationId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      result: json['result']?.toString() ?? 'UNKNOWN',
      conflictCode: json['conflictCode']?.toString(),
    );
  }
}

class AttendanceSessionResults {
  const AttendanceSessionResults({
    required this.sessionId,
    required this.status,
    required this.summary,
    required this.records,
  });

  final String sessionId;
  final String status;
  final Map<String, int> summary;
  final List<AttendanceRecordItem> records;

  factory AttendanceSessionResults.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final records = json['records'];
    return AttendanceSessionResults(
      sessionId: json['sessionId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      summary: summary is Map
          ? summary.map(
              (key, value) => MapEntry(
                key.toString(),
                int.tryParse(value?.toString() ?? '') ?? 0,
              ),
            )
          : const {},
      records: records is List
          ? records
                .whereType<Map<String, dynamic>>()
                .map(AttendanceRecordItem.fromJson)
                .toList()
          : const [],
    );
  }
}

class AttendanceRecordItem {
  const AttendanceRecordItem({
    required this.rosterStudentId,
    required this.status,
    this.checkpointId,
    this.studentName,
    this.method,
    this.overrideReason,
  });

  final String rosterStudentId;
  final String status;
  final String? checkpointId;
  final String? studentName;
  final String? method;
  final String? overrideReason;

  factory AttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordItem(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString(),
      studentName: json['studentName']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      method: json['method']?.toString(),
      overrideReason:
          json['overrideReason']?.toString() ?? json['reason']?.toString(),
    );
  }
}

class OfflineSyncRecordResult {
  const OfflineSyncRecordResult({
    required this.attendanceSessionId,
    required this.rosterStudentId,
    required this.result,
  });

  final String attendanceSessionId;
  final String rosterStudentId;
  final String result;

  String get syncKey => '$attendanceSessionId::$rosterStudentId';

  factory OfflineSyncRecordResult.fromJson(Map<String, dynamic> json) {
    return OfflineSyncRecordResult(
      attendanceSessionId: json['attendanceSessionId']?.toString() ?? '',
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      result: json['result']?.toString() ?? 'UNKNOWN',
    );
  }
}

class GuideTourVehicle {
  const GuideTourVehicle({required this.id, required this.label});

  final String id;
  final String label;

  factory GuideTourVehicle.fromJson(Map<String, dynamic> json) {
    return GuideTourVehicle(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Xe',
    );
  }
}

class GuideTourItineraryCheckpoint {
  const GuideTourItineraryCheckpoint({
    required this.id,
    required this.sortOrder,
    required this.kind,
    required this.name,
    this.activityId,
    this.plannedStart,
    this.activityName,
    this.destinationName,
    this.progressStatus = 'PENDING',
    this.arrivedAt,
    this.completedAt,
  });

  final String id;
  final int sortOrder;
  final String kind;
  final String name;
  final String? activityId;
  final DateTime? plannedStart;
  final String? activityName;
  final String? destinationName;
  final String progressStatus;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  bool get isCurrent => progressStatus.toUpperCase() == 'CURRENT';
  bool get isArrived => progressStatus.toUpperCase() == 'ARRIVED';
  bool get isCompleted => progressStatus.toUpperCase() == 'COMPLETED';
  bool get canComplete => isCurrent || isArrived;

  factory GuideTourItineraryCheckpoint.fromJson(Map<String, dynamic> json) {
    return GuideTourItineraryCheckpoint(
      id: json['id']?.toString() ?? '',
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      kind: json['kind']?.toString() ?? 'NORMAL',
      name: json['name']?.toString() ?? 'Địa điểm',
      activityId: json['activityId']?.toString(),
      plannedStart: _parseDate(json['plannedStart']),
      activityName: json['activityName']?.toString(),
      destinationName: json['destinationName']?.toString(),
      progressStatus: json['progressStatus']?.toString() ?? 'PENDING',
      arrivedAt: _parseDate(json['arrivedAt'] ?? json['arrived_at']),
      completedAt: _parseDate(json['completedAt']),
    );
  }
}

class GuideTourItineraryItem {
  const GuideTourItineraryItem({
    required this.planItemId,
    required this.itemKind,
    required this.title,
    required this.sortOrder,
    required this.required,
    required this.executionStatus,
    required this.completed,
    this.checkpointId,
    this.checkpointName,
    this.checkpointKind,
    this.operationVehicleId,
    this.vehicleLabel,
    this.plannedStart,
    this.plannedEnd,
    this.activityId,
    this.activityName,
    this.destinationName,
    this.legType,
  });

  final String planItemId;
  final String itemKind;
  final String title;
  final int sortOrder;
  final bool required;
  final String executionStatus;
  final bool completed;
  final String? checkpointId;
  final String? checkpointName;
  final String? checkpointKind;
  final String? operationVehicleId;
  final String? vehicleLabel;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final String? activityId;
  final String? activityName;
  final String? destinationName;

  /// From attendance_config: BOARDING | ALIGHTING (null for non-attendance).
  final String? legType;

  factory GuideTourItineraryItem.fromJson(Map<String, dynamic> json) {
    final executionStatus =
        json['executionStatus']?.toString() ?? 'NOT_STARTED';
    return GuideTourItineraryItem(
      planItemId: json['planItemId']?.toString() ?? '',
      itemKind: json['itemKind']?.toString() ?? 'ATTENDANCE',
      title: json['title']?.toString() ?? 'Hoạt động',
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      required: json['required'] == true,
      executionStatus: executionStatus,
      completed:
          json['completed'] == true ||
          executionStatus.toUpperCase() == 'COMPLETED',
      checkpointId: json['checkpointId']?.toString(),
      checkpointName: json['checkpointName']?.toString(),
      checkpointKind: json['checkpointKind']?.toString(),
      operationVehicleId: json['operationVehicleId']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
      plannedStart: _parseDate(json['plannedStart']),
      plannedEnd: _parseDate(json['plannedEnd']),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString(),
      destinationName: json['destinationName']?.toString(),
      legType: json['legType']?.toString(),
    );
  }

  String get itemKindLabel => switch (itemKind.toUpperCase()) {
    'LIVESTREAM' => 'Livestream',
    'ATTENDANCE' => 'Điểm danh',
    'VEHICLE_INSPECTION' => 'Kiểm tra xe',
    _ => itemKind,
  };

  String get executionStatusLabel => switch (executionStatus.toUpperCase()) {
    'COMPLETED' => 'Hoàn thành',
    'IN_PROGRESS' => 'Đang thực hiện',
    'PARTIAL' => 'Một phần',
    'FAILED' => 'Chưa đạt',
    'WAITING_TEACHER' => 'Chờ giáo viên xác nhận',
    _ => 'Chưa bắt đầu',
  };

  bool get isVehicleInspection =>
      itemKind.toUpperCase() == 'VEHICLE_INSPECTION';

  bool get isAttendance => itemKind.toUpperCase() == 'ATTENDANCE';

  bool get hasAttendanceHistory {
    if (!isAttendance) return false;
    final status = executionStatus.toUpperCase();
    return completed ||
        status == 'COMPLETED' ||
        status == 'IN_PROGRESS' ||
        status == 'PARTIAL' ||
        status == 'FAILED';
  }

  bool get isLivestream => itemKind.toUpperCase() == 'LIVESTREAM';

  /// Kiểm soát sĩ số khi xuống xe (đến điểm) — đứng trước hoạt động / livestream.
  bool get isAlighting =>
      isAttendance && (legType ?? '').toUpperCase() == 'ALIGHTING';

  /// Điểm danh lên xe (đón / rời điểm) — đứng sau hoạt động.
  bool get isBoardingAttendance => isAttendance && !isAlighting;
}

class GuideTourItinerary {
  const GuideTourItinerary({
    required this.tourId,
    required this.myVehicleIds,
    required this.vehicles,
    required this.checkpoints,
    required this.items,
    this.operationVehicleId,
    this.currentCheckpointId,
    this.currentCheckpointName,
    this.nextCheckpointId,
    this.nextCheckpointName,
  });

  final String tourId;
  final List<String> myVehicleIds;
  final List<GuideTourVehicle> vehicles;
  final List<GuideTourItineraryCheckpoint> checkpoints;
  final List<GuideTourItineraryItem> items;
  final String? operationVehicleId;
  final String? currentCheckpointId;
  final String? currentCheckpointName;
  final String? nextCheckpointId;
  final String? nextCheckpointName;

  factory GuideTourItinerary.fromJson(Map<String, dynamic> json) {
    return GuideTourItinerary(
      tourId: json['tourId']?.toString() ?? '',
      myVehicleIds: (json['myVehicleIds'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      vehicles: (json['vehicles'] as List<dynamic>? ?? [])
          .map(
            (value) => GuideTourVehicle.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? [])
          .map(
            (value) => GuideTourItineraryCheckpoint.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (value) => GuideTourItineraryItem.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      operationVehicleId: json['operationVehicleId']?.toString(),
      currentCheckpointId: json['currentCheckpointId']?.toString(),
      currentCheckpointName: json['currentCheckpointName']?.toString(),
      nextCheckpointId: json['nextCheckpointId']?.toString(),
      nextCheckpointName: json['nextCheckpointName']?.toString(),
    );
  }

  GuideTourItineraryCheckpoint? checkpointById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final checkpoint in checkpoints) {
      if (checkpoint.id == id) return checkpoint;
    }
    return null;
  }

  /// True when the stop is marked COMPLETED, or progress has already moved past it.
  bool isCheckpointCompleted(String? id) {
    final checkpoint = checkpointById(id);
    if (checkpoint == null) return false;
    if (checkpoint.isCompleted) return true;

    final current = checkpointById(currentCheckpointId);
    if (current != null && checkpoint.sortOrder < current.sortOrder) {
      return true;
    }

    // No current stop left and this one isn't CURRENT → tour progressed past it.
    if ((currentCheckpointId == null || currentCheckpointId!.isEmpty) &&
        !checkpoint.isCurrent &&
        checkpoints.any((c) => c.isCompleted)) {
      return true;
    }
    return false;
  }

  /// Active stop for ops: matches [currentCheckpointId] (CURRENT or ARRIVED).
  bool isCheckpointOperable(String? id) {
    if (id == null || id.isEmpty) return false;
    if (currentCheckpointId != null && currentCheckpointId!.isNotEmpty) {
      return id == currentCheckpointId;
    }
    final checkpoint = checkpointById(id);
    return checkpoint != null &&
        (checkpoint.isCurrent || checkpoint.isArrived);
  }

  /// True when the vehicle has arrived, is at, or has finished this stop.
  bool hasReachedCheckpoint(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    if (isCheckpointOperable(id) || isCheckpointCompleted(id)) return true;
    final checkpoint = checkpointById(id);
    return checkpoint != null &&
        (checkpoint.isArrived || checkpoint.isCurrent || checkpoint.isCompleted);
  }

  /// Attendance / livestream / mutate actions are locked unless stop is current.
  bool isItemActionsLocked(GuideTourItineraryItem item) {
    final id = item.checkpointId;
    if (id == null || id.isEmpty) return false;
    return !isCheckpointOperable(id);
  }

  bool isCheckpointCurrent(String? id) => isCheckpointOperable(id);
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
