import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/attendance/data/datasources/offline_attendance_data_source.dart';
import 'package:ventourkid_mobile/features/attendance/domain/entities/offline_attendance.dart';
import 'package:ventourkid_mobile/features/face_attendance/domain/entities/mobile_face_embedding.dart';

void main() {
  group('OfflineAttendanceRepository.syncPending', () {
    test(
      'creates a server session before syncing local offline marks',
      () async {
        final localSession = _session('local-1');
        final serverSession = _session('server-1');
        final mark = _mark(attendanceSessionId: 'local-1');
        final remote = _FakeAttendanceRemoteDataSource(
          serverSession: serverSession,
        );
        final local = _FakeAttendanceLocalDataSource(
          activeSession: localSession,
          queue: [mark],
        );
        final repository = OfflineAttendanceRepository(
          remote: remote,
          local: local,
        );

        final summary = await repository.syncPending();

        expect(remote.startedSessions, hasLength(1));
        expect(remote.syncedRecords.single.attendanceSessionId, 'server-1');
        expect(local.activeSession?.sessionId, 'server-1');
        expect(await local.getQueue(), isEmpty);
        expect(summary.synced, 1);
      },
    );

    test(
      'syncs existing server session marks without creating a session',
      () async {
        final serverSession = _session('server-1');
        final mark = _mark(attendanceSessionId: 'server-1');
        final remote = _FakeAttendanceRemoteDataSource(
          serverSession: serverSession,
        );
        final local = _FakeAttendanceLocalDataSource(
          activeSession: serverSession,
          queue: [mark],
        );
        final repository = OfflineAttendanceRepository(
          remote: remote,
          local: local,
        );

        final summary = await repository.syncPending();

        expect(remote.startedSessions, isEmpty);
        expect(remote.syncedRecords.single.attendanceSessionId, 'server-1');
        expect(await local.getQueue(), isEmpty);
        expect(summary.synced, 1);
      },
    );
  });
}

AttendanceSessionDraft _session(String id) {
  return AttendanceSessionDraft(
    sessionId: id,
    planItemId: 'plan-item-1',
    tourId: 'tour-1',
    checkpointId: 'checkpoint-1',
    operationVehicleId: 'vehicle-1',
    status: 'OPEN',
    studentCount: 1,
    startedAt: DateTime.utc(2026, 8, 2),
    sessionName: 'Offline checkpoint',
    sessionType: 'MANUAL',
  );
}

OfflineAttendanceMark _mark({required String attendanceSessionId}) {
  return OfflineAttendanceMark(
    localId: 'mark-1',
    attendanceSessionId: attendanceSessionId,
    planItemId: 'plan-item-1',
    rosterStudentId: 'student-1',
    finalStatus: 'PRESENT',
    recordedAt: DateTime.utc(2026, 8, 2, 1),
    reason: 'Mobile offline attendance',
    studentName: 'Student One',
    tourId: 'tour-1',
    checkpointId: 'checkpoint-1',
  );
}

class _FakeAttendanceRemoteDataSource implements AttendanceRemoteDataSource {
  _FakeAttendanceRemoteDataSource({required this.serverSession});

  final AttendanceSessionDraft serverSession;
  final startedSessions = <AttendanceSessionDraft>[];
  final syncedRecords = <OfflineAttendanceMark>[];

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
    startedSessions.add(serverSession);
    return serverSession;
  }

  @override
  Future<OfflineSyncSummary> syncOffline(
    List<OfflineAttendanceMark> records, {
    List<OfflineSyncCommand> commands = const [],
  }) async {
    syncedRecords.addAll(records);
    return OfflineSyncSummary(
      synced: records.length,
      conflicts: 0,
      records: records
          .map(
            (record) => OfflineSyncRecordResult(
              attendanceSessionId: record.attendanceSessionId,
              rosterStudentId: record.rosterStudentId,
              result: 'SYNCED',
            ),
          )
          .toList(),
      commands: const [],
    );
  }

  @override
  Future<AttendanceSessionResults> closeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> completeCheckpoint({
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PreTripChecklist> getPreTripChecklist(String tourId) =>
      throw UnimplementedError();

  @override
  Future<PreTripChecklist> updatePreTripChecklist({
    required String tourId,
    required List<PreTripChecklistItem> items,
    required bool confirm,
  }) => throw UnimplementedError();

  @override
  Future<VehicleInspectionOtpResult> sendVehicleInspectionOtp({
    required String tourId,
    required String planItemId,
    String? operationVehicleId,
  }) => throw UnimplementedError();

  @override
  Future<VehicleInspectionConfirmResult> confirmVehicleInspection({
    required String tourId,
    required String planItemId,
    required String otpCode,
    required Map<String, bool> checks,
    String? operationVehicleId,
  }) => throw UnimplementedError();

  @override
  Future<AttendanceSessionResults> getSessionResults(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<GuideTourItinerary> getTourItinerary(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceTour>> listActiveTours() {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceTour>> listUpcomingTours({int days = 30}) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceTour>> listTourHistory({int days = 30}) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceCheckpoint>> listCheckpoints(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<OfflineFaceTemplate>> listFaceTemplates(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceSessionSummary>> listSessions(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceStudent>> listStudents(
    String tourId, {
    String? operationVehicleId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceRecordItem> overrideRecord({
    required String sessionId,
    required String rosterStudentId,
    required String finalStatus,
    String? checkpointId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
}

class _FakeAttendanceLocalDataSource implements AttendanceLocalDataSource {
  _FakeAttendanceLocalDataSource({
    required this.activeSession,
    required List<OfflineAttendanceMark> queue,
  }) : _queue = [...queue];

  AttendanceSessionDraft? activeSession;
  List<OfflineAttendanceMark> _queue;

  @override
  Future<void> applySyncSummary(OfflineSyncSummary summary) async {
    final syncedKeys = summary.records
        .where((record) => record.result == 'SYNCED')
        .map((record) => record.syncKey)
        .toSet();
    _queue = _queue
        .where((record) => !syncedKeys.contains(record.syncKey))
        .toList();
  }

  @override
  Future<void> clearActiveSession() async {
    activeSession = null;
  }

  @override
  Future<AttendanceSessionDraft?> getActiveSession() async {
    return activeSession;
  }

  @override
  Future<List<OfflineAttendanceMark>> getPendingQueue({
    String? sessionId,
  }) async {
    return _queue
        .where(
          (record) =>
              record.isPendingSync &&
              (sessionId == null || record.attendanceSessionId == sessionId),
        )
        .toList();
  }

  @override
  Future<List<OfflineAttendanceMark>> getQueue() async {
    return [..._queue];
  }

  @override
  Future<List<OfflineSyncCommand>> getCommandQueue() async => const [];

  @override
  Future<List<OfflineSyncCommand>> getPendingCommands({String? sessionId}) async =>
      const [];

  @override
  Future<void> replacePendingSessionId({
    required String localSessionId,
    required AttendanceSessionDraft serverSession,
  }) async {
    _queue = _queue
        .map(
          (record) => record.attendanceSessionId == localSessionId
              ? record.copyWith(attendanceSessionId: serverSession.sessionId)
              : record,
        )
        .toList();
    if (activeSession?.sessionId == localSessionId) {
      activeSession = serverSession;
    }
  }

  @override
  Future<void> saveActiveSession(AttendanceSessionDraft session) async {
    activeSession = session;
  }

  @override
  Future<void> upsertMark(OfflineAttendanceMark mark) async {
    _queue.add(mark);
  }

  @override
  Future<void> upsertCommand(OfflineSyncCommand command) async {}

  @override
  Future<List<AttendanceCheckpoint>> getCachedCheckpoints(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<OfflineFaceTemplate>> getCachedFaceTemplates(String tourId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceStudent>> getCachedStudents(
    String tourId, {
    String? operationVehicleId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceTour>> getCachedTours() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveCheckpoints(
    String tourId,
    List<AttendanceCheckpoint> checkpoints,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveFaceTemplates(
    String tourId,
    List<OfflineFaceTemplate> templates,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveStudents(
    String tourId,
    List<AttendanceStudent> students, {
    String? operationVehicleId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveTours(List<AttendanceTour> tours) {
    throw UnimplementedError();
  }
}
