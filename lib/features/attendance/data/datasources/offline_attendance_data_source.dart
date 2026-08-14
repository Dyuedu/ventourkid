import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../face_attendance/domain/entities/mobile_face_embedding.dart';
import '../../domain/entities/offline_attendance.dart';
import '../../domain/entities/tour_attendance_history.dart';

abstract interface class AttendanceRemoteDataSource {
  Future<List<AttendanceTour>> listActiveTours();

  Future<List<AttendanceTour>> listUpcomingTours({int days = 30});

  Future<List<AttendanceTour>> listTourHistory({int days = 30});

  Future<List<AttendanceCheckpoint>> listCheckpoints(String tourId);

  Future<GuideTourItinerary> getTourItinerary(String tourId);

  Future<PreTripChecklist> getPreTripChecklist(String tourId);

  Future<PreTripChecklist> updatePreTripChecklist({
    required String tourId,
    required List<PreTripChecklistItem> items,
    required bool confirm,
  });

  Future<VehicleInspectionOtpResult> sendVehicleInspectionOtp({
    required String tourId,
    required String planItemId,
    String? operationVehicleId,
  });

  Future<VehicleInspectionConfirmResult> confirmVehicleInspection({
    required String tourId,
    required String planItemId,
    required String otpCode,
    required Map<String, bool> checks,
    String? operationVehicleId,
  });

  Future<Map<String, dynamic>> completeCheckpoint({
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
  });

  Future<List<AttendanceSessionSummary>> listSessions(String tourId);

  Future<List<AttendanceStudent>> listStudents(
    String tourId, {
    String? operationVehicleId,
  });

  Future<List<FieldFoodAllergyAlert>> listFoodAllergyAlerts(String tourId);

  Future<AttendanceSessionDraft> startSession({
    required String planItemId,
    required String tourId,
    required String checkpointId,
    required String operationVehicleId,
    String? sessionName,
    String sessionType = 'MANUAL',
    List<String> groupIds = const [],
  });

  Future<AttendanceSessionResults> closeSession(String sessionId);

  Future<List<OfflineFaceTemplate>> listFaceTemplates(String tourId);

  Future<AttendanceSessionResults> getSessionResults(String sessionId);

  Future<TourAttendanceHistory> getTourAttendanceHistory(
    String tourId, {
    String? planItemId,
    String? checkpointId,
  });

  Future<AttendanceRecordItem> overrideRecord({
    required String sessionId,
    required String rosterStudentId,
    required String finalStatus,
    String? checkpointId,
    required String reason,
  });

  Future<OfflineSyncSummary> syncOffline(
    List<OfflineAttendanceMark> records, {
    List<OfflineSyncCommand> commands = const [],
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  const AttendanceRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<List<AttendanceTour>> listActiveTours() async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours',
    );
    return _dataList(response.data).map(AttendanceTour.fromJson).toList();
  }

  @override
  Future<List<AttendanceTour>> listUpcomingTours({int days = 30}) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/upcoming-tours',
      queryParameters: {'days': days},
    );
    return _dataList(response.data).map(AttendanceTour.fromJson).toList();
  }

  @override
  Future<List<AttendanceTour>> listTourHistory({int days = 30}) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/tour-history',
      queryParameters: {'days': days},
    );
    return _dataList(response.data).map(AttendanceTour.fromJson).toList();
  }

  @override
  Future<List<AttendanceCheckpoint>> listCheckpoints(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/checkpoints',
    );
    return _dataList(response.data).map(AttendanceCheckpoint.fromJson).toList();
  }

  @override
  Future<GuideTourItinerary> getTourItinerary(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/itinerary',
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid itinerary response');
    }
    return GuideTourItinerary.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<PreTripChecklist> getPreTripChecklist(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/pretrip-checklist',
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid pre-trip checklist response');
    }
    return PreTripChecklist.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<PreTripChecklist> updatePreTripChecklist({
    required String tourId,
    required List<PreTripChecklistItem> items,
    required bool confirm,
  }) async {
    final response = await _dio.dio.put<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/pretrip-checklist',
      data: {
        'items': items.map((item) => item.toUpdateJson()).toList(),
        'confirm': confirm,
      },
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid pre-trip checklist response');
    }
    return PreTripChecklist.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<VehicleInspectionOtpResult> sendVehicleInspectionOtp({
    required String tourId,
    required String planItemId,
    String? operationVehicleId,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/vehicle-inspection/otp',
      data: {
        'planItemId': planItemId,
        if (operationVehicleId != null && operationVehicleId.isNotEmpty)
          'operationVehicleId': operationVehicleId,
      },
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid vehicle inspection OTP response');
    }
    return VehicleInspectionOtpResult.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<VehicleInspectionConfirmResult> confirmVehicleInspection({
    required String tourId,
    required String planItemId,
    required String otpCode,
    required Map<String, bool> checks,
    String? operationVehicleId,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/vehicle-inspection/confirm',
      data: {
        'planItemId': planItemId,
        'otpCode': otpCode,
        'checks': checks,
        if (operationVehicleId != null && operationVehicleId.isNotEmpty)
          'operationVehicleId': operationVehicleId,
      },
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException(
        'Invalid vehicle inspection confirm response',
      );
    }
    return VehicleInspectionConfirmResult.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  @override
  Future<Map<String, dynamic>> completeCheckpoint({
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/vehicles/$operationVehicleId/checkpoints/$checkpointId/complete',
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  @override
  Future<List<AttendanceSessionSummary>> listSessions(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/sessions',
    );
    return _dataList(
      response.data,
    ).map(AttendanceSessionSummary.fromJson).toList();
  }

  @override
  Future<List<AttendanceStudent>> listStudents(
    String tourId, {
    String? operationVehicleId,
  }) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/students',
      queryParameters: {
        if (operationVehicleId != null && operationVehicleId.isNotEmpty)
          'operationVehicleId': operationVehicleId,
      },
    );
    return _dataList(response.data).map(AttendanceStudent.fromJson).toList();
  }

  @override
  Future<List<FieldFoodAllergyAlert>> listFoodAllergyAlerts(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/food-allergy-alerts',
    );
    return _dataList(response.data)
        .map(FieldFoodAllergyAlert.fromJson)
        .toList();
  }

  @override
  Future<AttendanceSessionDraft> startSession({
    required String planItemId,
    required String tourId,
    required String checkpointId,
    required String operationVehicleId,
    String? sessionName,
    String sessionType = 'MANUAL',
    List<String> groupIds = const [],
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/attendance/sessions/start',
      data: {
        'planItemId': planItemId,
        'tourId': tourId,
        'checkpointId': checkpointId,
        'operationVehicleId': operationVehicleId,
        if (sessionName != null && sessionName.trim().isNotEmpty)
          'sessionName': sessionName.trim(),
        'sessionType': sessionType,
        if (groupIds.isNotEmpty) 'groupIds': groupIds,
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid attendance session response');
    }
    return AttendanceSessionDraft.fromJson({
      ...data,
      'planItemId': planItemId,
      'tourId': tourId,
      'operationVehicleId': operationVehicleId,
      'sessionName': sessionName,
      'sessionType': sessionType,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<AttendanceSessionResults> closeSession(String sessionId) async {
    await _dio.dio.post<Map<String, dynamic>>(
      '/v1/attendance/sessions/$sessionId/close',
    );
    return getSessionResults(sessionId);
  }

  @override
  Future<List<OfflineFaceTemplate>> listFaceTemplates(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/face/offline/active-tours/$tourId/embeddings',
    );
    return _dataList(response.data).map(OfflineFaceTemplate.fromJson).toList();
  }

  @override
  Future<AttendanceSessionResults> getSessionResults(String sessionId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/sessions/$sessionId/results',
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid attendance session results');
    }
    return AttendanceSessionResults.fromJson(data);
  }

  @override
  Future<TourAttendanceHistory> getTourAttendanceHistory(
    String tourId, {
    String? planItemId,
    String? checkpointId,
  }) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/attendance/active-tours/$tourId/history',
      queryParameters: {
        if (planItemId != null && planItemId.trim().isNotEmpty)
          'planItemId': planItemId.trim(),
        if (checkpointId != null && checkpointId.trim().isNotEmpty)
          'checkpointId': checkpointId.trim(),
      },
    );
    final raw = response.data?['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid tour attendance history response');
    }
    return TourAttendanceHistory.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<AttendanceRecordItem> overrideRecord({
    required String sessionId,
    required String rosterStudentId,
    required String finalStatus,
    String? checkpointId,
    required String reason,
  }) async {
    final response = await _dio.dio.put<Map<String, dynamic>>(
      '/v1/attendance/sessions/$sessionId/records/$rosterStudentId/override',
      data: {
        'finalStatus': finalStatus,
        'reason': reason,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid attendance override response');
    }
    return AttendanceRecordItem.fromJson({
      ...data,
      'status': data['finalStatus'],
    });
  }

  @override
  Future<OfflineSyncSummary> syncOffline(
    List<OfflineAttendanceMark> records, {
    List<OfflineSyncCommand> commands = const [],
  }) async {
    if (records.isEmpty && commands.isEmpty) {
      return OfflineSyncSummary.empty();
    }
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/offline/sync',
      data: {
        if (records.isNotEmpty)
          'records': records.map((record) => record.toSyncJson()).toList(),
        if (commands.isNotEmpty)
          'commands': commands.map((command) => command.toSyncJson()).toList(),
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid offline sync response');
    }
    return OfflineSyncSummary.fromJson(data);
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }
}

abstract interface class AttendanceLocalDataSource {
  Future<List<AttendanceTour>> getCachedTours();

  Future<void> saveTours(List<AttendanceTour> tours);

  Future<List<AttendanceCheckpoint>> getCachedCheckpoints(String tourId);

  Future<void> saveCheckpoints(
    String tourId,
    List<AttendanceCheckpoint> checkpoints,
  );

  Future<List<AttendanceStudent>> getCachedStudents(
    String tourId, {
    String? operationVehicleId,
  });

  Future<void> saveStudents(
    String tourId,
    List<AttendanceStudent> students, {
    String? operationVehicleId,
  });

  Future<List<OfflineFaceTemplate>> getCachedFaceTemplates(String tourId);

  Future<void> saveFaceTemplates(
    String tourId,
    List<OfflineFaceTemplate> templates,
  );

  Future<AttendanceSessionDraft?> getActiveSession();

  Future<void> saveActiveSession(AttendanceSessionDraft session);

  Future<void> clearActiveSession();

  Future<List<OfflineAttendanceMark>> getQueue();

  Future<List<OfflineAttendanceMark>> getPendingQueue({String? sessionId});

  Future<void> upsertMark(OfflineAttendanceMark mark);

  Future<List<OfflineSyncCommand>> getCommandQueue();

  Future<List<OfflineSyncCommand>> getPendingCommands({String? sessionId});

  Future<void> upsertCommand(OfflineSyncCommand command);

  Future<void> replacePendingSessionId({
    required String localSessionId,
    required AttendanceSessionDraft serverSession,
  });

  Future<void> applySyncSummary(OfflineSyncSummary summary);
}

class AttendanceLocalDataSourceImpl implements AttendanceLocalDataSource {
  static const _toursKey = 'attendance.offline.tours';
  static const _activeSessionKey = 'attendance.offline.activeSession';
  static const _queueKey = 'attendance.offline.queue';
  static const _commandsKey = 'attendance.offline.commands';
  static const _checkpointsPrefix = 'attendance.offline.checkpoints.';
  static const _studentsPrefix = 'attendance.offline.students.';
  static const _faceTemplatesPrefix = 'attendance.offline.faceTemplates.';

  const AttendanceLocalDataSourceImpl();

  @override
  Future<List<AttendanceTour>> getCachedTours() async {
    final rows = await _readList(_toursKey);
    return rows.map(AttendanceTour.fromJson).toList();
  }

  @override
  Future<void> saveTours(List<AttendanceTour> tours) async {
    await _writeList(_toursKey, tours.map((tour) => tour.toJson()).toList());
  }

  @override
  Future<List<AttendanceCheckpoint>> getCachedCheckpoints(String tourId) async {
    final rows = await _readList('$_checkpointsPrefix$tourId');
    return rows.map(AttendanceCheckpoint.fromJson).toList();
  }

  @override
  Future<void> saveCheckpoints(
    String tourId,
    List<AttendanceCheckpoint> checkpoints,
  ) async {
    await _writeList(
      '$_checkpointsPrefix$tourId',
      checkpoints.map((checkpoint) => checkpoint.toJson()).toList(),
    );
  }

  String _studentsCacheKey(String tourId, String? operationVehicleId) {
    if (operationVehicleId == null || operationVehicleId.isEmpty) {
      return '$_studentsPrefix$tourId';
    }
    return '$_studentsPrefix$tourId::$operationVehicleId';
  }

  @override
  Future<List<AttendanceStudent>> getCachedStudents(
    String tourId, {
    String? operationVehicleId,
  }) async {
    final rows = await _readList(_studentsCacheKey(tourId, operationVehicleId));
    return rows.map(AttendanceStudent.fromJson).toList();
  }

  @override
  Future<void> saveStudents(
    String tourId,
    List<AttendanceStudent> students, {
    String? operationVehicleId,
  }) async {
    await _writeList(
      _studentsCacheKey(tourId, operationVehicleId),
      students.map((student) => student.toJson()).toList(),
    );
  }

  @override
  Future<List<OfflineFaceTemplate>> getCachedFaceTemplates(
    String tourId,
  ) async {
    final rows = await _readList('$_faceTemplatesPrefix$tourId');
    return rows.map(OfflineFaceTemplate.fromJson).toList();
  }

  @override
  Future<void> saveFaceTemplates(
    String tourId,
    List<OfflineFaceTemplate> templates,
  ) async {
    await _writeList(
      '$_faceTemplatesPrefix$tourId',
      templates.map((template) => template.toJson()).toList(),
    );
  }

  @override
  Future<AttendanceSessionDraft?> getActiveSession() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_activeSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AttendanceSessionDraft.fromJson(decoded);
      }
    } on FormatException {
      await preferences.remove(_activeSessionKey);
    }
    return null;
  }

  @override
  Future<void> saveActiveSession(AttendanceSessionDraft session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _activeSessionKey,
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeSessionKey);
  }

  @override
  Future<List<OfflineAttendanceMark>> getQueue() async {
    final rows = await _readList(_queueKey);
    return rows.map(OfflineAttendanceMark.fromJson).toList();
  }

  @override
  Future<List<OfflineAttendanceMark>> getPendingQueue({
    String? sessionId,
  }) async {
    final queue = await getQueue();
    return queue
        .where(
          (record) =>
              record.isPendingSync &&
              (sessionId == null || record.attendanceSessionId == sessionId),
        )
        .toList();
  }

  @override
  Future<void> upsertMark(OfflineAttendanceMark mark) async {
    final queue = await getQueue();
    final index = queue.indexWhere((record) => record.syncKey == mark.syncKey);
    if (index >= 0) {
      queue[index] = mark;
    } else {
      queue.add(mark);
    }
    await _saveQueue(queue);
  }

  @override
  Future<List<OfflineSyncCommand>> getCommandQueue() async {
    final rows = await _readList(_commandsKey);
    return rows.map(OfflineSyncCommand.fromJson).toList();
  }

  @override
  Future<List<OfflineSyncCommand>> getPendingCommands({
    String? sessionId,
  }) async {
    final queue = await getCommandQueue();
    return queue
        .where(
          (command) =>
              command.isPendingSync &&
              (sessionId == null ||
                  command.payload['attendanceSessionId']?.toString() ==
                      sessionId),
        )
        .toList();
  }

  @override
  Future<void> upsertCommand(OfflineSyncCommand command) async {
    final queue = await getCommandQueue();
    final index = queue.indexWhere(
      (record) => record.syncKey == command.syncKey,
    );
    if (index >= 0) {
      queue[index] = command;
    } else {
      queue.add(command);
    }
    await _saveCommandQueue(queue);
  }

  @override
  Future<void> replacePendingSessionId({
    required String localSessionId,
    required AttendanceSessionDraft serverSession,
  }) async {
    final queue = await getQueue();
    final next = queue.map((record) {
      if (record.attendanceSessionId != localSessionId ||
          !record.isPendingSync) {
        return record;
      }
      return record.copyWith(attendanceSessionId: serverSession.sessionId);
    }).toList();
    await _saveQueue(next);

    final commandQueue = await getCommandQueue();
    final nextCommands = commandQueue.map((command) {
      final sessionId = command.payload['attendanceSessionId']?.toString();
      if (sessionId != localSessionId || !command.isPendingSync) {
        return command;
      }
      return command.copyWith(
        payload: {
          ...command.payload,
          'attendanceSessionId': serverSession.sessionId,
        },
      );
    }).toList();
    await _saveCommandQueue(nextCommands);

    final activeSession = await getActiveSession();
    if (activeSession?.sessionId == localSessionId) {
      await saveActiveSession(
        AttendanceSessionDraft(
          sessionId: serverSession.sessionId,
          planItemId: serverSession.planItemId,
          tourId: serverSession.tourId,
          checkpointId: serverSession.checkpointId,
          operationVehicleId: serverSession.operationVehicleId,
          status: activeSession!.status,
          studentCount: serverSession.studentCount,
          startedAt: serverSession.startedAt,
          closedAt: activeSession.closedAt ?? serverSession.closedAt,
          sessionName: serverSession.sessionName,
          sessionType: serverSession.sessionType,
        ),
      );
    }
  }

  @override
  Future<void> applySyncSummary(OfflineSyncSummary summary) async {
    if (summary.records.isNotEmpty) {
      final resultByKey = {
        for (final record in summary.records) record.syncKey: record.result,
      };
      final queue = await getQueue();
      final next = <OfflineAttendanceMark>[];
      for (final mark in queue) {
        final result = resultByKey[mark.syncKey];
        if (result == null) {
          next.add(mark);
        } else if (result != 'SYNCED') {
          next.add(mark.copyWith(syncResult: result));
        }
      }
      await _saveQueue(next);
    }

    if (summary.commands.isNotEmpty) {
      final resultByKey = {
        for (final command in summary.commands) command.syncKey: command.result,
      };
      final queue = await getCommandQueue();
      final next = <OfflineSyncCommand>[];
      for (final command in queue) {
        final result = resultByKey[command.syncKey];
        if (result == null) {
          next.add(command);
        } else if (result != 'SYNCED') {
          next.add(command.copyWith(syncResult: result));
        }
      }
      await _saveCommandQueue(next);
    }
  }

  Future<void> _saveQueue(List<OfflineAttendanceMark> queue) async {
    await _writeList(
      _queueKey,
      queue.map((record) => record.toJson()).toList(),
    );
  }

  Future<void> _saveCommandQueue(List<OfflineSyncCommand> queue) async {
    await _writeList(
      _commandsKey,
      queue.map((record) => record.toJson()).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } on FormatException {
      await preferences.remove(key);
    }
    return const [];
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(rows));
  }
}

class OfflineAttendanceRepository {
  const OfflineAttendanceRepository({
    required AttendanceRemoteDataSource remote,
    required AttendanceLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final AttendanceRemoteDataSource _remote;
  final AttendanceLocalDataSource _local;

  Future<List<AttendanceTour>> getCachedTours() => _local.getCachedTours();

  Future<List<AttendanceTour>> refreshTours() async {
    final tours = await _remote.listActiveTours();
    await _local.saveTours(tours);
    return tours;
  }

  Future<List<AttendanceTour>> listUpcomingTours({int days = 30}) {
    return _remote.listUpcomingTours(days: days);
  }

  Future<List<AttendanceTour>> listTourHistory({int days = 30}) {
    return _remote.listTourHistory(days: days);
  }

  Future<List<AttendanceCheckpoint>> getCachedCheckpoints(String tourId) {
    return _local.getCachedCheckpoints(tourId);
  }

  Future<List<AttendanceCheckpoint>> refreshCheckpoints(String tourId) async {
    final checkpoints = await _remote.listCheckpoints(tourId);
    await _local.saveCheckpoints(tourId, checkpoints);
    return checkpoints;
  }

  Future<GuideTourItinerary> getTourItinerary(String tourId) {
    return _remote.getTourItinerary(tourId);
  }

  Future<PreTripChecklist> getPreTripChecklist(String tourId) {
    return _remote.getPreTripChecklist(tourId);
  }

  Future<PreTripChecklist> updatePreTripChecklist({
    required String tourId,
    required List<PreTripChecklistItem> items,
    required bool confirm,
  }) {
    return _remote.updatePreTripChecklist(
      tourId: tourId,
      items: items,
      confirm: confirm,
    );
  }

  Future<VehicleInspectionOtpResult> sendVehicleInspectionOtp({
    required String tourId,
    required String planItemId,
    String? operationVehicleId,
  }) {
    return _remote.sendVehicleInspectionOtp(
      tourId: tourId,
      planItemId: planItemId,
      operationVehicleId: operationVehicleId,
    );
  }

  Future<VehicleInspectionConfirmResult> confirmVehicleInspection({
    required String tourId,
    required String planItemId,
    required String otpCode,
    required Map<String, bool> checks,
    String? operationVehicleId,
  }) {
    return _remote.confirmVehicleInspection(
      tourId: tourId,
      planItemId: planItemId,
      otpCode: otpCode,
      checks: checks,
      operationVehicleId: operationVehicleId,
    );
  }

  Future<Map<String, dynamic>> completeCheckpoint({
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
  }) {
    return _remote.completeCheckpoint(
      tourId: tourId,
      operationVehicleId: operationVehicleId,
      checkpointId: checkpointId,
    );
  }

  Future<List<AttendanceSessionSummary>> refreshSessions(String tourId) {
    return _remote.listSessions(tourId);
  }

  Future<List<AttendanceStudent>> getCachedStudents(
    String tourId, {
    String? operationVehicleId,
  }) {
    return _local.getCachedStudents(
      tourId,
      operationVehicleId: operationVehicleId,
    );
  }

  Future<List<AttendanceStudent>> refreshStudents(
    String tourId, {
    String? operationVehicleId,
  }) async {
    final students = await _remote.listStudents(
      tourId,
      operationVehicleId: operationVehicleId,
    );
    await _local.saveStudents(
      tourId,
      students,
      operationVehicleId: operationVehicleId,
    );
    return students;
  }

  Future<List<FieldFoodAllergyAlert>> listFoodAllergyAlerts(String tourId) {
    return _remote.listFoodAllergyAlerts(tourId);
  }

  Future<AttendanceSessionDraft?> getActiveSession() {
    return _local.getActiveSession();
  }

  Future<AttendanceSessionDraft> startSession({
    required String planItemId,
    required String tourId,
    required String checkpointId,
    required String operationVehicleId,
    String? sessionName,
    String sessionType = 'MANUAL',
  }) async {
    AttendanceSessionDraft session;
    try {
      session = await _remote.startSession(
        planItemId: planItemId,
        tourId: tourId,
        checkpointId: checkpointId,
        operationVehicleId: operationVehicleId,
        sessionName: sessionName,
        sessionType: sessionType,
      );
    } on Object catch (error) {
      if (!_looksOffline(error)) rethrow;
      final students = await _local.getCachedStudents(
        tourId,
        operationVehicleId: operationVehicleId,
      );
      final now = DateTime.now().toUtc();
      session = AttendanceSessionDraft(
        sessionId: 'local-${now.microsecondsSinceEpoch}',
        planItemId: planItemId,
        tourId: tourId,
        checkpointId: checkpointId,
        operationVehicleId: operationVehicleId,
        status: 'OPEN',
        studentCount: students.length,
        startedAt: now,
        sessionName: sessionName,
        sessionType: sessionType,
      );
    }
    await _local.saveActiveSession(session);
    return session;
  }

  Future<List<OfflineFaceTemplate>> getCachedFaceTemplates(String tourId) {
    return _local.getCachedFaceTemplates(tourId);
  }

  Future<List<OfflineFaceTemplate>> refreshFaceTemplates(String tourId) async {
    final templates = await _remote.listFaceTemplates(tourId);
    await _local.saveFaceTemplates(tourId, templates);
    return templates;
  }

  Future<AttendanceSessionResults> getSessionResults(String sessionId) {
    return _remote.getSessionResults(sessionId);
  }

  Future<TourAttendanceHistory> getTourAttendanceHistory(
    String tourId, {
    String? planItemId,
    String? checkpointId,
  }) {
    return _remote.getTourAttendanceHistory(
      tourId,
      planItemId: planItemId,
      checkpointId: checkpointId,
    );
  }

  Future<AttendanceSessionResults> closeSession(String sessionId) {
    return _remote.closeSession(sessionId);
  }

  Future<void> queueCloseSession(AttendanceSessionDraft session) async {
    final now = DateTime.now().toUtc();
    final mutationId = _clientMutationId(now);
    await _local.upsertCommand(
      OfflineSyncCommand(
        localId: 'cmd-close-${session.sessionId}-${now.microsecondsSinceEpoch}',
        clientMutationId: mutationId,
        type: 'ATTENDANCE_SESSION_CLOSE',
        clientCreatedAt: now,
        payload: {
          'attendanceSessionId': session.sessionId,
          'planItemId': session.planItemId,
          'tourId': session.tourId,
          'checkpointId': session.checkpointId,
        },
      ),
    );
    await _local.saveActiveSession(
      AttendanceSessionDraft(
        sessionId: session.sessionId,
        planItemId: session.planItemId,
        tourId: session.tourId,
        checkpointId: session.checkpointId,
        operationVehicleId: session.operationVehicleId,
        status: 'CLOSED',
        studentCount: session.studentCount,
        startedAt: session.startedAt,
        closedAt: now,
        sessionName: session.sessionName,
        sessionType: session.sessionType,
      ),
    );
  }

  Future<AttendanceRecordItem> overrideRecord({
    required String sessionId,
    required String rosterStudentId,
    required String finalStatus,
    String? checkpointId,
    required String reason,
  }) {
    return _remote.overrideRecord(
      sessionId: sessionId,
      rosterStudentId: rosterStudentId,
      finalStatus: finalStatus,
      checkpointId: checkpointId,
      reason: reason,
    );
  }

  Future<List<OfflineAttendanceMark>> getQueue() => _local.getQueue();

  Future<List<OfflineAttendanceMark>> getPendingQueue({String? sessionId}) {
    return _local.getPendingQueue(sessionId: sessionId);
  }

  Future<List<OfflineSyncCommand>> getCommandQueue() {
    return _local.getCommandQueue();
  }

  Future<List<OfflineSyncCommand>> getPendingCommands({String? sessionId}) {
    return _local.getPendingCommands(sessionId: sessionId);
  }

  Future<void> markStudent({
    required AttendanceSessionDraft session,
    required AttendanceStudent student,
    required String finalStatus,
    String? reason,
  }) {
    final now = DateTime.now().toUtc();
    final mark = OfflineAttendanceMark(
      localId:
          '${session.sessionId}_${student.rosterStudentId}_${now.microsecondsSinceEpoch}',
      attendanceSessionId: session.sessionId,
      planItemId: session.planItemId,
      rosterStudentId: student.rosterStudentId,
      finalStatus: finalStatus,
      recordedAt: now,
      reason: reason ?? 'Mobile offline attendance',
      studentName: student.fullName,
      tourId: session.tourId,
      checkpointId: session.checkpointId,
    );
    return _local.upsertMark(mark);
  }

  Future<OfflineSyncSummary> syncPending({String? sessionId}) async {
    final effectiveSessionId = await _materializeLocalSessionsBeforeSync(
      sessionId: sessionId,
    );
    final records = await _local.getPendingQueue(sessionId: effectiveSessionId);
    final commands = await _local.getPendingCommands(
      sessionId: effectiveSessionId,
    );
    final summary = await _remote.syncOffline(records, commands: commands);
    await _local.applySyncSummary(summary);
    return summary;
  }

  Future<String?> _materializeLocalSessionsBeforeSync({
    String? sessionId,
  }) async {
    var records = await _local.getPendingQueue(sessionId: sessionId);
    var commands = await _local.getPendingCommands(sessionId: sessionId);
    final localSessionIds = {
      ...records
          .map((record) => record.attendanceSessionId)
          .where((id) => id.startsWith('local-')),
      ...commands
          .map((command) => command.payload['attendanceSessionId']?.toString())
          .whereType<String>()
          .where((id) => id.startsWith('local-')),
    };
    if (localSessionIds.isEmpty) {
      return sessionId;
    }

    String? remappedRequestedSessionId = sessionId;
    for (final localSessionId in localSessionIds) {
      final localSession = await _resolveLocalSessionForSync(localSessionId);
      final serverSession = await _remote.startSession(
        planItemId: localSession.planItemId,
        tourId: localSession.tourId,
        checkpointId: localSession.checkpointId,
        operationVehicleId: localSession.operationVehicleId,
        sessionName: localSession.sessionName,
        sessionType: localSession.sessionType ?? 'MANUAL',
      );
      await _local.replacePendingSessionId(
        localSessionId: localSessionId,
        serverSession: serverSession,
      );
      if (sessionId == localSessionId) {
        remappedRequestedSessionId = serverSession.sessionId;
      }
    }

    records = await _local.getPendingQueue(
      sessionId: remappedRequestedSessionId,
    );
    commands = await _local.getPendingCommands(
      sessionId: remappedRequestedSessionId,
    );
    if (records.any(
          (record) => record.attendanceSessionId.startsWith('local-'),
        ) ||
        commands.any(
          (command) =>
              command.payload['attendanceSessionId']?.toString().startsWith(
                'local-',
              ) ==
              true,
        )) {
      throw StateError(
        'Some offline attendance sessions could not be prepared for sync.',
      );
    }
    return remappedRequestedSessionId;
  }

  Future<AttendanceSessionDraft> _resolveLocalSessionForSync(
    String localSessionId,
  ) async {
    final activeSession = await _local.getActiveSession();
    if (activeSession != null && activeSession.sessionId == localSessionId) {
      return activeSession;
    }
    throw StateError(
      'Offline session $localSessionId is missing its local session metadata. '
      'Open that cached tour/checkpoint again before syncing.',
    );
  }
}

bool _looksOffline(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('connection') ||
      text.contains('timed out') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection reset');
}

String _clientMutationId(DateTime time) {
  final micros = time.microsecondsSinceEpoch.toRadixString(16);
  final padded = micros.padLeft(12, '0');
  return '00000000-0000-4000-8000-${padded.substring(padded.length - 12)}';
}
