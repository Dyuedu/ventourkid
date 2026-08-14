import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../face_attendance/data/services/mobile_face_embedding_service.dart';
import '../../../face_attendance/domain/entities/mobile_face_embedding.dart';
import '../../../face_attendance/presentation/widgets/live_face_capture_panel.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../domain/entities/offline_attendance.dart';

enum OfflineAttendanceMode { face, manual }

enum _AttendanceContentView { scanner, students }

class OfflineAttendancePage extends ConsumerStatefulWidget {
  const OfflineAttendancePage({
    super.key,
    this.initialTourId,
    this.initialMode = OfflineAttendanceMode.manual,
    this.initialPlanItemId,
    this.initialCheckpointId,
    this.initialVehicleId,
    this.initialSessionName,
    this.autoStartSession = false,
    this.fromItinerary = false,
  });

  final String? initialTourId;
  final OfflineAttendanceMode initialMode;
  final String? initialPlanItemId;
  final String? initialCheckpointId;
  final String? initialVehicleId;
  final String? initialSessionName;
  final bool autoStartSession;
  final bool fromItinerary;

  @override
  ConsumerState<OfflineAttendancePage> createState() =>
      _OfflineAttendancePageState();
}

class _OfflineAttendancePageState extends ConsumerState<OfflineAttendancePage> {
  final _searchController = TextEditingController();
  final _sessionNameController = TextEditingController();

  List<AttendanceTour> _tours = const [];
  List<AttendanceCheckpoint> _checkpoints = const [];
  List<AttendanceSessionSummary> _sessions = const [];
  List<AttendanceStudent> _students = const [];
  List<OfflineFaceTemplate> _faceTemplates = const [];
  List<OfflineAttendanceMark> _queue = const [];
  List<OfflineSyncCommand> _commands = const [];
  AttendanceSessionResults? _sessionResults;
  AttendanceSessionDraft? _activeSession;
  String? _selectedTourId;
  String? _selectedPlanItemId;
  String? _selectedCheckpointId;
  String? _selectedVehicleId;
  AttendanceStudent? _lastFaceStudent;
  XFile? _lastFaceFile;
  bool _loading = true;
  bool _loadingCheckpoints = false;
  bool _loadingStudents = false;
  bool _loadingFaceTemplates = false;
  bool _loadingResults = false;
  bool _startingSession = false;
  bool _closingSession = false;
  bool _processingFace = false;
  bool _syncing = false;
  bool _hasConnection = true;
  int _faceScanRound = 0;
  late OfflineAttendanceMode _mode;
  _AttendanceContentView _contentView = _AttendanceContentView.students;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _contentView = widget.initialMode == OfflineAttendanceMode.face
        ? _AttendanceContentView.scanner
        : _AttendanceContentView.students;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    _sessionNameController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refreshConnectivity();
    await _loadLocalSnapshot();
    await _refreshTours(showSuccess: false);
    if (_hasConnection) {
      unawaited(_autoSyncPending());
    }
    if (widget.fromItinerary) {
      await _prepareItineraryLaunch();
    }
    final sessionId = _activeSession?.sessionId;
    if (_hasConnection && sessionId != null && sessionId.isNotEmpty) {
      await _loadSessionResults();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _prepareItineraryLaunch() async {
    final tourId = widget.initialTourId;
    final planItemId = widget.initialPlanItemId;
    if (tourId == null ||
        tourId.isEmpty ||
        planItemId == null ||
        planItemId.isEmpty) {
      return;
    }

    if ((widget.initialSessionName ?? '').trim().isNotEmpty) {
      _sessionNameController.text = widget.initialSessionName!.trim();
    }

    // Drop stale local OPEN session from another tour/checkpoint/vehicle so
    // itinerary UI does not pretend marks are allowed.
    final stale = _activeSession;
    final staleMismatch =
        stale != null &&
        (stale.tourId != tourId ||
            stale.planItemId != planItemId ||
            (widget.initialCheckpointId != null &&
                widget.initialCheckpointId!.isNotEmpty &&
                stale.checkpointId != widget.initialCheckpointId) ||
            (widget.initialVehicleId != null &&
                widget.initialVehicleId!.isNotEmpty &&
                stale.operationVehicleId != widget.initialVehicleId) ||
            stale.status.toUpperCase() != 'OPEN');

    setState(() {
      if (staleMismatch) {
        _activeSession = null;
      }
      _selectedTourId = tourId;
      _selectedPlanItemId = planItemId;
      _selectedCheckpointId = widget.initialCheckpointId;
      _selectedVehicleId = widget.initialVehicleId;
    });

    await Future.wait([
      _loadCheckpoints(tourId, refresh: true),
      _loadStudents(tourId, refresh: true),
      _loadSessions(tourId),
    ]);

    if (!mounted) return;

    final checkpoint = _checkpoints
        .where((item) => item.planItemId == planItemId)
        .firstOrNull;
    setState(() {
      _selectedPlanItemId = planItemId;
      _selectedCheckpointId =
          widget.initialCheckpointId ?? checkpoint?.checkpointId;
      if (widget.initialVehicleId != null &&
          widget.initialVehicleId!.isNotEmpty) {
        _selectedVehicleId = widget.initialVehicleId;
      } else {
        _selectedVehicleId = _vehicleOrFirst(_selectedVehicleId, _students);
      }
      if (_sessionNameController.text.trim().isEmpty) {
        _sessionNameController.text = checkpoint?.name ?? 'Phiên điểm danh';
      }
    });

    if (!widget.autoStartSession) return;

    final existingOpen = _sessionsForSelectedCheckpoint
        .where((session) => session.status.toUpperCase() == 'OPEN')
        .firstOrNull;
    if (existingOpen != null) {
      await _selectSession(existingOpen);
      if (mounted) {
        setState(() {
          _message = 'Phiên điểm danh đang mở theo lịch trình.';
        });
      }
      return;
    }

    await _startSession();
    if (mounted && _activeSession?.status.toUpperCase() == 'OPEN') {
      setState(() {
        _message = 'Phiên điểm danh đang mở theo lịch trình.';
      });
    }
  }

  Future<void> _refreshConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChanged(results);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final connected = results.any((result) {
      return result != ConnectivityResult.none;
    });
    if (!mounted) {
      _hasConnection = connected;
      return;
    }
    setState(() {
      _hasConnection = connected;
      if (connected && _contentView == _AttendanceContentView.scanner) {
        _contentView = _AttendanceContentView.students;
      }
    });
    if (connected) {
      final sessionId = _activeSession?.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        unawaited(_loadSessionResults());
      }
      unawaited(_autoSyncPending());
    }
  }

  Future<void> _loadLocalSnapshot() async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final activeSession = await repository.getActiveSession();
    final tours = await repository.getCachedTours();
    final selectedTourId =
        activeSession?.tourId ??
        widget.initialTourId ??
        _selectedTourId ??
        (tours.isNotEmpty ? tours.first.tourId : null);
    final checkpoints = selectedTourId == null
        ? const <AttendanceCheckpoint>[]
        : await repository.getCachedCheckpoints(selectedTourId);
    final selectedPlanItemId =
        activeSession?.planItemId ??
        _planItemOrFirst(_selectedPlanItemId, checkpoints);
    final selectedCheckpointId =
        activeSession?.checkpointId ??
        checkpoints
            .where((item) => item.planItemId == selectedPlanItemId)
            .firstOrNull
            ?.checkpointId;
    final vehicleId =
        activeSession?.operationVehicleId ??
        widget.initialVehicleId ??
        _selectedVehicleId;
    final students = selectedTourId == null
        ? const <AttendanceStudent>[]
        : await repository.getCachedStudents(
            selectedTourId,
            operationVehicleId: vehicleId,
          );
    final faceTemplates = selectedTourId == null
        ? const <OfflineFaceTemplate>[]
        : await repository.getCachedFaceTemplates(selectedTourId);
    final queue = await repository.getQueue();
    final commands = await repository.getCommandQueue();

    if (!mounted) return;
    setState(() {
      _activeSession = activeSession;
      _tours = tours;
      _checkpoints = checkpoints;
      _selectedTourId = selectedTourId;
      _selectedPlanItemId = selectedPlanItemId;
      _selectedCheckpointId = selectedCheckpointId;
      _selectedVehicleId =
          activeSession?.operationVehicleId ??
          _vehicleOrFirst(_selectedVehicleId, students);
      _students = students;
      _faceTemplates = faceTemplates;
      _queue = queue;
      _commands = commands;
    });
  }

  Future<void> _refreshTours({bool showSuccess = true}) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    try {
      final tours = await repository.refreshTours();
      final selectedTourId = _tourOrFirst(
        _selectedTourId ?? widget.initialTourId,
        tours,
      );
      if (!mounted) return;
      setState(() {
        _tours = tours;
        _selectedTourId = selectedTourId;
        _message = showSuccess ? 'Đã cập nhật danh sách tour.' : _message;
        _error = null;
      });
      if (selectedTourId != null) {
        await Future.wait([
          _loadCheckpoints(selectedTourId, refresh: true),
          _loadSessions(selectedTourId),
          _loadStudents(selectedTourId, refresh: true),
          _loadFaceTemplates(selectedTourId, refresh: true),
        ]);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _message = _tours.isNotEmpty
            ? 'Đang dùng dữ liệu tour đã lưu trên máy.'
            : null;
        _error = _tours.isEmpty ? 'Chưa tải được tour để điểm danh.' : null;
      });
    }
  }

  Future<void> _loadCheckpoints(String tourId, {required bool refresh}) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    setState(() {
      _loadingCheckpoints = true;
      _selectedTourId = tourId;
      _error = null;
    });

    final cachedCheckpoints = await repository.getCachedCheckpoints(tourId);
    if (mounted) {
      setState(() {
        _checkpoints = cachedCheckpoints;
        _selectAttendanceItem(cachedCheckpoints, tourId);
      });
    }

    if (!refresh) {
      if (mounted) {
        setState(() => _loadingCheckpoints = false);
      }
      return;
    }

    try {
      final checkpoints = await repository.refreshCheckpoints(tourId);
      if (!mounted) return;
      setState(() {
        _checkpoints = checkpoints;
        _selectAttendanceItem(checkpoints, tourId);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _message = cachedCheckpoints.isNotEmpty
            ? 'Đang dùng checkpoint đã lưu trên máy.'
            : _message;
        _error = cachedCheckpoints.isEmpty ? 'Chưa tải được checkpoint.' : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCheckpoints = false);
      }
    }
  }

  void _selectAttendanceItem(List<AttendanceCheckpoint> items, String tourId) {
    final planItemId = _activeSession?.tourId == tourId
        ? _activeSession?.planItemId
        : _planItemOrFirst(_selectedPlanItemId, items);
    final selected = items
        .where((item) => item.planItemId == planItemId)
        .firstOrNull;
    _selectedPlanItemId = selected?.planItemId;
    _selectedCheckpointId = selected?.checkpointId;
  }

  Future<void> _loadStudents(String tourId, {required bool refresh}) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final vehicleId = _selectedVehicleId;
    setState(() {
      _loadingStudents = true;
      _selectedTourId = tourId;
      _error = null;
    });

    final cachedStudents = await repository.getCachedStudents(
      tourId,
      operationVehicleId: vehicleId,
    );
    if (mounted) {
      setState(() {
        _students = cachedStudents;
        _selectedVehicleId = _vehicleOrFirst(
          _selectedVehicleId,
          cachedStudents,
        );
      });
    }

    if (!refresh) {
      if (mounted) {
        setState(() => _loadingStudents = false);
      }
      return;
    }

    try {
      final students = await repository.refreshStudents(
        tourId,
        operationVehicleId: vehicleId,
      );
      final queue = await repository.getQueue();
      if (!mounted) return;
      setState(() {
        _students = students;
        _selectedVehicleId = _vehicleOrFirst(_selectedVehicleId, students);
        _queue = queue;
        _message = 'Đã cập nhật roster ${students.length} học sinh.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _message = cachedStudents.isNotEmpty
            ? 'Đang dùng roster đã lưu trên máy.'
            : null;
        _error = cachedStudents.isEmpty ? 'Chưa tải được roster.' : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingStudents = false);
      }
    }
  }

  Future<void> _loadSessions(String tourId) async {
    if (!_hasConnection) {
      if (mounted) {
        setState(() => _sessions = const []);
      }
      return;
    }
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    try {
      final sessions = await repository.refreshSessions(tourId);
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(
          error,
          fallback: 'Chưa tải được danh sách session điểm danh.',
        );
      });
    }
  }

  Future<void> _loadFaceTemplates(
    String tourId, {
    required bool refresh,
  }) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    setState(() {
      _loadingFaceTemplates = true;
      _selectedTourId = tourId;
      _error = null;
    });

    final cachedTemplates = await repository.getCachedFaceTemplates(tourId);
    if (mounted) {
      setState(() => _faceTemplates = cachedTemplates);
    }

    if (!refresh) {
      if (mounted) {
        setState(() => _loadingFaceTemplates = false);
      }
      return;
    }

    try {
      final templates = await repository.refreshFaceTemplates(tourId);
      if (!mounted) return;
      setState(() {
        _faceTemplates = templates;
        if (_mode == OfflineAttendanceMode.face) {
          _message = 'Đã tải ${templates.length} mẫu khuôn mặt offline.';
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _message = cachedTemplates.isNotEmpty
            ? 'Đang dùng mẫu khuôn mặt đã lưu trên máy.'
            : _message;
        _error = cachedTemplates.isEmpty && _mode == OfflineAttendanceMode.face
            ? 'Chưa tải được mẫu khuôn mặt để điểm danh khuôn mặt offline.'
            : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFaceTemplates = false);
      }
    }
  }

  Future<void> _startSession({OfflineAttendanceMode? mode}) async {
    final tourId = _selectedTourId;
    final planItemId = _selectedPlanItemId;
    final checkpointId = _selectedCheckpointId;
    final vehicleId = _selectedVehicleId;
    if (tourId == null || tourId.isEmpty) {
      _setError('Chọn tour trước khi mở phiên điểm danh.');
      return;
    }
    if (checkpointId == null || checkpointId.isEmpty) {
      _setError('Chọn checkpoint trước khi mở phiên điểm danh.');
      return;
    }
    if (vehicleId == null || vehicleId.isEmpty) {
      _setError('Chọn xe trước khi mở phiên điểm danh.');
      return;
    }
    if (planItemId == null || planItemId.isEmpty) {
      _setError('Mốc điểm danh chưa được nối với kế hoạch vận hành.');
      return;
    }

    setState(() {
      _startingSession = true;
      _message = null;
      _error = null;
    });

    try {
      final session = await ref
          .read(offlineAttendanceRepositoryProvider)
          .startSession(
            planItemId: planItemId,
            tourId: tourId,
            checkpointId: checkpointId,
            operationVehicleId: vehicleId,
            sessionName: _sessionNameController.text,
            sessionType: _sessionType(mode ?? _mode),
          );
      final queue = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getQueue();
      if (!mounted) return;
      setState(() {
        _activeSession = session;
        _queue = queue;
        _mode = mode ?? _mode;
        _contentView = _mode == OfflineAttendanceMode.face && !_hasConnection
            ? _AttendanceContentView.scanner
            : _AttendanceContentView.students;
        _message =
            'Đã mở phiên điểm danh cho ${session.studentCount} học sinh.';
      });
      if (_hasConnection) {
        await _loadSessions(tourId);
        await _loadSessionResults();
      }
    } on Object catch (error) {
      _setError(
        _friendlyError(error, fallback: 'Chưa mở được phiên điểm danh.'),
      );
    } finally {
      if (mounted) {
        setState(() => _startingSession = false);
      }
    }
  }

  Future<void> _selectSession(AttendanceSessionSummary summary) async {
    final tourId = _selectedTourId;
    if (tourId == null) return;
    final checkpoint = _checkpoints
            .where((item) => item.planItemId == (summary.planItemId ?? _selectedPlanItemId))
            .firstOrNull ??
        _checkpoints
            .where((item) => item.checkpointId == summary.checkpointId)
            .firstOrNull;
    final session = AttendanceSessionDraft(
      sessionId: summary.sessionId,
      planItemId:
          summary.planItemId ?? checkpoint?.planItemId ?? _selectedPlanItemId ?? '',
      tourId: tourId,
      checkpointId: summary.checkpointId,
      operationVehicleId: _selectedVehicleId ?? '',
      status: summary.status,
      studentCount: _filteredStudents.length,
      startedAt: summary.startedAt ?? DateTime.now().toUtc(),
      sessionName: summary.sessionName,
      sessionType: summary.sessionType,
    );
    try {
      final results = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getSessionResults(summary.sessionId);
      if (!mounted) return;
      setState(() {
        _activeSession = session;
        _selectedPlanItemId =
            summary.planItemId ?? checkpoint?.planItemId ?? _selectedPlanItemId;
        _selectedCheckpointId = summary.checkpointId;
        _sessionResults = results;
        _mode = (summary.sessionType ?? '').toUpperCase() == 'FACE'
            ? OfflineAttendanceMode.face
            : OfflineAttendanceMode.manual;
        _contentView = _AttendanceContentView.students;
        _message = summary.status.toUpperCase() == 'CLOSED'
            ? 'Session đã kết thúc. Danh sách bên dưới là kết quả đã chốt.'
            : 'Đã chọn session điểm danh.';
        _error = null;
      });
    } on Object catch (error) {
      _setError(
        _friendlyError(error, fallback: 'Chưa tải được session điểm danh.'),
      );
    }
  }

  Future<void> _closeSession() async {
    final session = _activeSession;
    if (session == null || session.sessionId.isEmpty) {
      _setError('Chọn hoặc mở session trước khi kết thúc.');
      return;
    }
    setState(() {
      _closingSession = true;
      _message = null;
      _error = null;
    });
    if (!_hasConnection || session.sessionId.startsWith('local-')) {
      await _queueCloseSession(session);
      if (mounted) {
        setState(() => _closingSession = false);
      }
      return;
    }
    try {
      final results = await ref
          .read(offlineAttendanceRepositoryProvider)
          .closeSession(session.sessionId);
      if (!mounted) return;
      setState(() {
        _sessionResults = results;
        _activeSession = AttendanceSessionDraft(
          sessionId: session.sessionId,
          planItemId: session.planItemId,
          tourId: session.tourId,
          checkpointId: session.checkpointId,
          operationVehicleId: session.operationVehicleId,
          status: 'CLOSED',
          studentCount: session.studentCount,
          startedAt: session.startedAt,
          sessionName: session.sessionName,
          sessionType: session.sessionType,
        );
        _message =
            'Đã đóng phiên. Học sinh chưa điểm danh được đánh vắng tự động. '
            'Danh sách bên dưới là kết quả đã chốt.';
      });
      await _loadSessions(session.tourId);
    } on Object catch (error) {
      if (_looksOffline(error)) {
        if (mounted) {
          setState(() => _hasConnection = false);
        }
        await _queueCloseSession(session);
      } else {
        _setError(
          _friendlyError(error, fallback: 'Chưa kết thúc được session.'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _closingSession = false);
      }
    }
  }

  Future<void> _queueCloseSession(AttendanceSessionDraft session) async {
    await ref
        .read(offlineAttendanceRepositoryProvider)
        .queueCloseSession(session);
    final commands = await ref
        .read(offlineAttendanceRepositoryProvider)
        .getCommandQueue();
    final activeSession = await ref
        .read(offlineAttendanceRepositoryProvider)
        .getActiveSession();
    if (!mounted) return;
    setState(() {
      _commands = commands;
      _activeSession = activeSession ?? _activeSession;
      _message =
          'Đã lưu lệnh đóng phiên trên máy. Khi có mạng, app sẽ đồng bộ bản ghi và đóng phiên trên server.';
      _error = null;
    });
  }

  Future<void> _handleManualStudentStatusSelected(
    AttendanceStudent student,
    String status,
  ) async {
    final normalizedStatus = status.toUpperCase();
    String? reason;
    if (_mode == OfflineAttendanceMode.manual && normalizedStatus == 'ABSENT') {
      reason = await _showAbsentReasonDialog(student);
      if (reason == null) return;
    }
    if (!mounted) return;
    await _markStudent(student, normalizedStatus, reason: reason);
  }

  Future<String?> _showAbsentReasonDialog(AttendanceStudent student) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AbsentReasonDialog(
        studentName: student.fullName,
      ),
    );
  }

  Future<void> _markStudent(
    AttendanceStudent student,
    String status, {
    String? reason,
  }) async {
    final session = _activeSession;
    if (session == null || session.tourId != _selectedTourId) {
      _setError('Mở phiên điểm danh cho tour này trước.');
      return;
    }
    if (session.status.toUpperCase() == 'CLOSED') {
      _setError(
        'Phiên đã đóng — không thể sửa Có/Vắng. Mở phiên mới nếu cần cập nhật.',
      );
      return;
    }

    if (_hasConnection) {
      try {
        await ref
            .read(offlineAttendanceRepositoryProvider)
            .overrideRecord(
              sessionId: session.sessionId,
              rosterStudentId: student.rosterStudentId,
              finalStatus: status,
              checkpointId: _selectedCheckpointId,
              reason: reason ?? 'Cập nhật thủ công từ mobile',
            );
        await _loadSessionResults();
        if (!mounted) return;
        setState(() {
          _message =
              '${student.fullName}: ${_statusLabel(status)} đã cập nhật.';
          _error = null;
        });
        return;
      } on Object catch (error) {
        if (!_looksOffline(error)) {
          _setError(
            _friendlyError(error, fallback: 'Chưa cập nhật được điểm danh.'),
          );
          return;
        }
        if (mounted) {
          setState(() => _hasConnection = false);
        }
      }
    }

    await ref
        .read(offlineAttendanceRepositoryProvider)
        .markStudent(
          session: session,
          student: student,
          finalStatus: status,
          reason: reason,
        );
    final queue = await ref
        .read(offlineAttendanceRepositoryProvider)
        .getQueue();
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _message = '${student.fullName}: ${_statusLabel(status)} đã lưu cục bộ.';
      _error = null;
    });
  }

  Future<void> _loadSessionResults() async {
    final sessionId = _activeSession?.sessionId;
    if (sessionId == null || sessionId.isEmpty || !_hasConnection) return;
    setState(() {
      _loadingResults = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getSessionResults(sessionId);
      if (!mounted) return;
      setState(() => _sessionResults = results);
    } on Object catch (error) {
      if (!mounted) return;
      if (_looksOffline(error)) {
        setState(() {
          _hasConnection = false;
          _message = 'Thiết bị mất kết nối. Đã chuyển sang chế độ offline.';
        });
      } else {
        setState(() {
          _error = _friendlyError(
            error,
            fallback: 'Chưa tải được trạng thái điểm danh.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingResults = false);
      }
    }
  }

  Future<void> _onOfflineFaceCaptured(
    XFile file,
    MobileFaceDetectionResult detection,
  ) async {
    final session = _activeSession;
    if (!mounted || _processingFace) return;
    if (_hasConnection) {
      _setError(
        'Thiết bị đang có mạng. Chỉ dùng khuôn mặt offline khi mất kết nối.',
      );
      await _deleteQuietly(file.path);
      return;
    }
    if (session == null || session.tourId != _selectedTourId) {
      _setError('Mở phiên điểm danh trước khi quét khuôn mặt offline.');
      await _deleteQuietly(file.path);
      return;
    }
    if (_faceTemplates.isEmpty) {
      _setError('Chưa có mẫu khuôn mặt offline cho tour này.');
      await _deleteQuietly(file.path);
      return;
    }

    setState(() {
      _processingFace = true;
      _lastFaceFile = file;
      _lastFaceStudent = null;
      _message = 'Đang nhận diện khuôn mặt trên máy…';
      _error = null;
    });

    try {
      final probe = await ref
          .read(mobileFaceEmbeddingServiceProvider)
          .createEmbedding(file.path);
      final match = _bestFaceMatch(probe.embedding);
      if (match == null || match.score < 0.72) {
        if (!mounted) return;
        setState(() {
          _message = null;
          _error = 'Không tìm thấy học sinh phù hợp trong cache offline.';
          _faceScanRound += 1;
        });
        return;
      }
      final student = _studentByRosterId(match.template.rosterStudentId);
      if (student == null) {
        if (!mounted) return;
        setState(() {
          _message = null;
          _error = 'Mẫu khuôn mặt không khớp roster đã cache.';
          _faceScanRound += 1;
        });
        return;
      }

      await ref
          .read(offlineAttendanceRepositoryProvider)
          .markStudent(
            session: session,
            student: student,
            finalStatus: 'PRESENT',
          );
      final queue = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getQueue();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _lastFaceStudent = student;
        _message =
            '${student.fullName}${student.className == null ? '' : ' - lớp ${student.className}'} đã điểm danh thành công. Chuẩn bị quét học sinh tiếp theo.';
        _error = null;
      });
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted &&
            _mode == OfflineAttendanceMode.face &&
            !_processingFace) {
          _resetFaceScan();
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      _setError(_friendlyError(error, fallback: 'Chưa quét được khuôn mặt.'));
    } finally {
      if (mounted) {
        setState(() => _processingFace = false);
      }
    }
  }

  Future<void> _resetFaceScan() async {
    final file = _lastFaceFile;
    if (file != null) {
      await _deleteQuietly(file.path);
    }
    if (!mounted) return;
    setState(() {
      _lastFaceFile = null;
      _lastFaceStudent = null;
      _message = null;
      _error = null;
      _faceScanRound += 1;
    });
  }

  Future<void> _openOnlineFaceScanner() async {
    final tourId = _selectedTourId;
    if (tourId == null || tourId.isEmpty) {
      _setError('Chọn tour trước khi quét khuôn mặt.');
      return;
    }
    if (_selectedCheckpointId == null || _selectedCheckpointId!.isEmpty) {
      _setError('Chọn lịch điểm danh trước khi quét khuôn mặt.');
      return;
    }
    if (_selectedVehicleId == null || _selectedVehicleId!.isEmpty) {
      _setError('Chọn xe điểm danh trước khi quét khuôn mặt.');
      return;
    }

    AttendanceTour? selectedTour;
    for (final tour in _tours) {
      if (tour.tourId == tourId) {
        selectedTour = tour;
        break;
      }
    }
    final checkpoint = _checkpoints
        .where((item) => item.checkpointId == _selectedCheckpointId)
        .firstOrNull;
    final vehicleId = _selectedVehicleId!;

    await context.push(
      Uri(
        path: '/face-attendance',
        queryParameters: {
          'tourId': tourId,
          'tourName': selectedTour?.tourName ?? '',
          'checkpointId': _selectedCheckpointId!,
          if (checkpoint != null)
            'checkpointLabel':
                '${checkpoint.sortOrder + 1}. ${checkpoint.name} (${checkpoint.kind})',
          'vehicleId': vehicleId,
          'vehicleLabel': _vehicleDisplayLabel(vehicleId),
        },
      ).toString(),
    );
    if (!mounted) return;
    await _loadSessionResults();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _autoSyncPending() async {
    if (_syncing || !_hasConnection) return;
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final pendingRecords = await repository.getPendingQueue();
    final pendingCommands = await repository.getPendingCommands();
    if (!mounted ||
        !_hasConnection ||
        _syncing ||
        (pendingRecords.isEmpty && pendingCommands.isEmpty)) {
      return;
    }
    await _syncPending(showSnackBar: false, automatic: true);
  }

  Future<void> _syncPending({
    bool showSnackBar = true,
    bool automatic = false,
  }) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final pending =
        (await repository.getPendingQueue()).length +
        (await repository.getPendingCommands()).length;
    if (pending == 0) {
      if (!automatic && mounted) {
        setState(() {
          _message = 'Không có bản ghi chờ đồng bộ.';
          _error = null;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _syncing = true;
      _message = null;
      _error = null;
    });

    try {
      final summary = await repository.syncPending();
      final queue = await repository.getQueue();
      final commands = await repository.getCommandQueue();
      final activeSession = await repository.getActiveSession();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _commands = commands;
        _activeSession = activeSession ?? _activeSession;
        _message = automatic
            ? 'Đã tự động đồng bộ ${summary.synced} bản ghi, ${summary.conflicts} xung đột.'
            : 'Đã đồng bộ ${summary.synced} bản ghi, ${summary.conflicts} xung đột.';
      });
      if (!showSnackBar || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đồng bộ xong: ${summary.synced} bản ghi'
            '${summary.conflicts > 0 ? ', ${summary.conflicts} xung đột' : ''}.',
          ),
        ),
      );
    } on Object catch (error) {
      _setError(
        _friendlyError(
          error,
          fallback: 'Chưa đồng bộ được. Bản ghi vẫn lưu trên máy.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _message = null;
    });
  }

  List<AttendanceStudent> get _filteredStudents {
    final vehicleId = _selectedVehicleId;
    Iterable<AttendanceStudent> source = _students;
    if (vehicleId != null && vehicleId.isNotEmpty) {
      source = source.where(
        (student) => student.operationVehicleId == vehicleId,
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source.toList();
    return source.where((student) {
      final haystack = [
        student.fullName,
        student.studentCode ?? '',
        student.className ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Map<String, OfflineAttendanceMark> get _marksByStudent {
    final sessionId = _activeSession?.sessionId;
    return {
      for (final mark in _queue)
        if (mark.attendanceSessionId == sessionId) mark.rosterStudentId: mark,
    };
  }

  Map<String, AttendanceRecordItem> get _recordsByStudent {
    return {
      for (final record
          in _sessionResults?.records ?? const <AttendanceRecordItem>[])
        if (record.rosterStudentId.isNotEmpty) record.rosterStudentId: record,
    };
  }

  List<AttendanceSessionSummary> get _sessionsForSelectedCheckpoint {
    final planItemId = (_selectedPlanItemId ?? '').trim();
    final checkpointId = _selectedCheckpointId;
    return _sessions.where((session) {
      final sessionPlanItemId = (session.planItemId ?? '').trim();
      if (planItemId.isNotEmpty) {
        if (sessionPlanItemId.isNotEmpty) {
          return sessionPlanItemId == planItemId;
        }
        if (checkpointId == null || session.checkpointId != checkpointId) {
          return false;
        }
        final itemsAtCheckpoint = _checkpoints
            .where((item) => item.checkpointId == checkpointId)
            .length;
        return itemsAtCheckpoint <= 1;
      }
      return checkpointId != null &&
          checkpointId.isNotEmpty &&
          session.checkpointId == checkpointId;
    }).toList();
  }

  int get _pendingCount =>
      _queue.where((record) => record.isPendingSync).length +
      _commands.where((command) => command.isPendingSync).length;

  int get _conflictCount =>
      _queue.where((record) => !record.isPendingSync).length +
      _commands.where((command) => !command.isPendingSync).length;

  int get _markedCount {
    final records = _recordsByStudent;
    if (_hasConnection && records.isNotEmpty) {
      return records.values
          .where((record) => record.status.toUpperCase() != 'PENDING')
          .length;
    }
    return _marksByStudent.length;
  }

  bool get _canMark =>
      _activeSession != null &&
      _activeSession!.tourId == _selectedTourId &&
      _activeSession!.status.toUpperCase() == 'OPEN';

  bool get _sessionClosed =>
      _activeSession != null &&
      _activeSession!.tourId == _selectedTourId &&
      _activeSession!.status.toUpperCase() == 'CLOSED';

  bool get _canFaceScan =>
      _mode == OfflineAttendanceMode.face &&
      !_hasConnection &&
      _canMark &&
      !_loading &&
      !_loadingStudents &&
      !_loadingFaceTemplates &&
      !_processingFace &&
      _lastFaceStudent == null;

  bool get _showFaceControls => _mode == OfflineAttendanceMode.face;

  /// Itinerary "session open" UI must match [_canMark], otherwise Có/Vắng stay
  /// disabled while "Mở phiên" is hidden (stale OPEN session from another tour).
  bool get _itinerarySessionOpen => widget.fromItinerary && _canMark;

  String _statusForStudent(AttendanceStudent student) {
    final localMark = _marksByStudent[student.rosterStudentId];
    if (localMark != null && localMark.isPendingSync) {
      return _normalizeAttendanceStatus(localMark.finalStatus);
    }
    final onlineRecord = _recordsByStudent[student.rosterStudentId];
    if (_hasConnection && onlineRecord != null) {
      return _normalizeAttendanceStatus(onlineRecord.status);
    }
    return _normalizeAttendanceStatus(localMark?.finalStatus ?? 'PENDING');
  }

  String? _absentReasonForStudent(AttendanceStudent student) {
    final localMark = _marksByStudent[student.rosterStudentId];
    if (_normalizeAttendanceStatus(localMark?.finalStatus ?? '') == 'ABSENT') {
      final localReason = localMark?.reason.trim();
      if (localReason != null && localReason.isNotEmpty) return localReason;
    }

    final onlineRecord = _recordsByStudent[student.rosterStudentId];
    if (_hasConnection &&
        onlineRecord != null &&
        _normalizeAttendanceStatus(onlineRecord.status) == 'ABSENT') {
      final onlineReason = onlineRecord.overrideReason?.trim();
      if (onlineReason != null && onlineReason.isNotEmpty) {
        return onlineReason;
      }
    }

    return null;
  }

  bool _pendingSyncForStudent(AttendanceStudent student) {
    return _marksByStudent[student.rosterStudentId]?.isPendingSync == true;
  }

  AttendanceStudent? _studentByRosterId(String rosterStudentId) {
    for (final student in _students) {
      if (student.rosterStudentId == rosterStudentId) return student;
    }
    return null;
  }

  _FaceTemplateMatch? _bestFaceMatch(List<double> embedding) {
    _FaceTemplateMatch? best;
    for (final template in _faceTemplates) {
      final score = _cosineSimilarity(embedding, template.embedding);
      if (score == null) continue;
      if (best == null || score > best.score) {
        best = _FaceTemplateMatch(template: template, score: score);
      }
    }
    return best;
  }

  List<String> get _vehicleIds {
    final ids = _students
        .map((student) => student.operationVehicleId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final selected = _selectedVehicleId;
    if (selected != null && selected.isNotEmpty && !ids.contains(selected)) {
      ids.insert(0, selected);
    }
    return ids;
  }

  String _vehicleDisplayLabel(String vehicleId) {
    for (final student in _students) {
      if (student.operationVehicleId == vehicleId) {
        final label = student.vehicleLabel?.trim();
        if (label != null && label.isNotEmpty) {
          return label;
        }
      }
    }
    if (vehicleId.length >= 8) {
      return 'Xe ${vehicleId.substring(0, 8)}';
    }
    return 'Xe $vehicleId';
  }

  @override
  Widget build(BuildContext context) {
    AttendanceTour? selectedTour;
    for (final tour in _tours) {
      if (tour.tourId == _selectedTourId) {
        selectedTour = tour;
        break;
      }
    }
    final filteredStudents = _filteredStudents;
    final marksByStudent = _marksByStudent;
    final showFaceScanner =
        _mode == OfflineAttendanceMode.face &&
        _contentView == _AttendanceContentView.scanner &&
        !_hasConnection;
    final showStudentList =
        _mode == OfflineAttendanceMode.manual ||
        _contentView == _AttendanceContentView.students ||
        _hasConnection;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: Text(_hasConnection ? 'Điểm danh' : 'Điểm danh offline'),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ bản ghi offline',
            onPressed: (_syncing || !_hasConnection) ? null : _syncPending,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () => _refreshTours(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusPanel(
                    session: _activeSession,
                    selectedTourName: selectedTour?.tourName,
                    pendingCount: _pendingCount,
                    conflictCount: _conflictCount,
                    markedCount: _markedCount,
                    studentCount: filteredStudents.length,
                  ),
                  const SizedBox(height: 12),
                  if (_itinerarySessionOpen) ...[
                    _ItinerarySessionBanner(
                      sessionName: _sessionNameController.text.trim().isEmpty
                          ? 'Phiên điểm danh'
                          : _sessionNameController.text.trim(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ConnectionModeBanner(
                    hasConnection: _hasConnection,
                    pendingCount: _pendingCount,
                  ),
                  const SizedBox(height: 12),
                  _Panel(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey(
                            'attendance-tour-${_selectedTourId ?? 'none'}-${_tours.length}',
                          ),
                          initialValue:
                              _selectedTourId != null &&
                                  _tours.any(
                                    (tour) => tour.tourId == _selectedTourId,
                                  )
                              ? _selectedTourId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Tour',
                            prefixIcon: Icon(Icons.route_outlined),
                          ),
                          items: _tours
                              .map(
                                (tour) => DropdownMenuItem(
                                  value: tour.tourId,
                                  child: Text(
                                    tour.tourName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loading || widget.fromItinerary
                              ? null
                              : (tourId) {
                                  if (tourId == null) return;
                                  Future.wait([
                                    _loadCheckpoints(tourId, refresh: true),
                                    _loadSessions(tourId),
                                    _loadStudents(tourId, refresh: true),
                                    _loadFaceTemplates(tourId, refresh: true),
                                  ]);
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey(
                            'attendance-plan-item-${_selectedPlanItemId ?? 'none'}-${_checkpoints.length}',
                          ),
                          initialValue:
                              _selectedPlanItemId != null &&
                                  _checkpoints.any(
                                    (item) =>
                                        item.planItemId == _selectedPlanItemId,
                                  )
                              ? _selectedPlanItemId
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Lịch điểm danh',
                            prefixIcon: _loadingCheckpoints
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.place_outlined),
                          ),
                          items: _checkpoints
                              .map(
                                (checkpoint) => DropdownMenuItem(
                                  value: checkpoint.planItemId,
                                  child: Text(
                                    '${checkpoint.sortOrder + 1}. ${checkpoint.name} (${checkpoint.kind})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingCheckpoints || widget.fromItinerary
                              ? null
                              : (planItemId) {
                                  final selected = _checkpoints
                                      .where(
                                        (item) => item.planItemId == planItemId,
                                      )
                                      .firstOrNull;
                                  setState(() {
                                    _selectedPlanItemId = planItemId;
                                    _selectedCheckpointId =
                                        selected?.checkpointId;
                                    _sessionResults = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _vehicleIds.contains(_selectedVehicleId)
                              ? _selectedVehicleId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Xe điểm danh',
                            prefixIcon: Icon(Icons.directions_bus_outlined),
                          ),
                          items: _vehicleIds
                              .map(
                                (vehicleId) => DropdownMenuItem(
                                  value: vehicleId,
                                  child: Text(
                                    _vehicleDisplayLabel(vehicleId),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingStudents || widget.fromItinerary
                              ? null
                              : (vehicleId) {
                                  setState(() {
                                    _selectedVehicleId = vehicleId;
                                  });
                                  final tourId = _selectedTourId;
                                  if (tourId != null && vehicleId != null) {
                                    _loadStudents(tourId, refresh: true);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _sessionNameController,
                          readOnly: widget.fromItinerary,
                          decoration: const InputDecoration(
                            labelText: 'Tên session',
                            prefixIcon: Icon(Icons.edit_note_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<OfflineAttendanceMode>(
                            selected: {_mode},
                            onSelectionChanged: (values) {
                              if (values.isEmpty) return;
                              setState(() {
                                _mode = values.first;
                                _contentView =
                                    _mode == OfflineAttendanceMode.face
                                    ? _AttendanceContentView.scanner
                                    : _AttendanceContentView.students;
                              });
                            },
                            segments: const [
                              ButtonSegment(
                                value: OfflineAttendanceMode.face,
                                icon: Icon(Icons.face_retouching_natural),
                                label: Text('Khuôn mặt'),
                              ),
                              ButtonSegment(
                                value: OfflineAttendanceMode.manual,
                                icon: Icon(Icons.fact_check_outlined),
                                label: Text('Thủ công'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    (_loadingStudents ||
                                        _loadingFaceTemplates ||
                                        _selectedTourId == null)
                                    ? null
                                    : () => Future.wait([
                                        _loadStudents(
                                          _selectedTourId!,
                                          refresh: true,
                                        ),
                                        _loadFaceTemplates(
                                          _selectedTourId!,
                                          refresh: true,
                                        ),
                                      ]),
                                icon: _loadingStudents || _loadingFaceTemplates
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download_done_outlined),
                                label: const Text('Tải roster'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!_itinerarySessionOpen)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _startingSession
                                      ? null
                                      : () => _startSession(mode: _mode),
                                  icon: _startingSession
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.play_circle_outline),
                                  label: Text(
                                    _sessionClosed
                                        ? 'Mở phiên mới'
                                        : 'Mở phiên',
                                  ),
                                ),
                              ),
                            if (!_itinerarySessionOpen)
                              const SizedBox(width: 8),
                            if (_itinerarySessionOpen || _canMark)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: (_closingSession || !_canMark)
                                      ? null
                                      : _closeSession,
                                  icon: _closingSession
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Đóng phiên'),
                                ),
                              )
                            else
                              IconButton.outlined(
                                tooltip: 'Kết thúc session',
                                onPressed: (_closingSession || !_canMark)
                                    ? null
                                    : _closeSession,
                                icon: _closingSession
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.stop_circle_outlined),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_showFaceControls) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _hasConnection
                                ? _openOnlineFaceScanner
                                : () {
                                    setState(() {
                                      _contentView =
                                          _AttendanceContentView.scanner;
                                      _lastFaceStudent = null;
                                      _lastFaceFile = null;
                                      _faceScanRound += 1;
                                    });
                                  },
                            icon: Icon(
                              _hasConnection
                                  ? Icons.cloud_upload_outlined
                                  : Icons.camera_alt_outlined,
                            ),
                            label: Text(
                              _hasConnection
                                  ? 'Quét khuôn mặt'
                                  : 'Quét offline',
                            ),
                          ),
                        ),
                        if (!_hasConnection &&
                            _contentView == _AttendanceContentView.scanner) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Xem danh sách',
                            onPressed: () {
                              setState(() {
                                _contentView = _AttendanceContentView.students;
                              });
                            },
                            icon: const Icon(Icons.groups_outlined),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_message != null) _Banner.success(_message!),
                  if (_error != null) _Banner.error(_error!),
                  if (showFaceScanner)
                    _OfflineFaceModeView(
                      key: ValueKey('offline-face-$_faceScanRound'),
                      faceService: ref.watch(
                        mobileFaceEmbeddingServiceProvider,
                      ),
                      enabled: _canFaceScan,
                      processing: _processingFace,
                      activeSession: _activeSession,
                      templateCount: _faceTemplates.length,
                      student: _lastFaceStudent,
                      imageFile: _lastFaceFile,
                      onCaptured: _onOfflineFaceCaptured,
                      onNext: _resetFaceScan,
                    ),
                  if (showStudentList) ...[
                    _Panel(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Tìm học sinh',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingResults) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (_loading)
                      const _LoadingBlock()
                    else if (filteredStudents.isEmpty)
                      const _EmptyBlock()
                    else ...[
                      if (!_canMark) ...[
                        Material(
                          color: _sessionClosed
                              ? AppTheme.accentGreen.withValues(alpha: 0.10)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _sessionClosed
                                      ? Icons.lock_outline_rounded
                                      : Icons.info_outline_rounded,
                                  size: 18,
                                  color: _sessionClosed
                                      ? AppTheme.accentGreen
                                      : const Color(0xFF9A3412),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _sessionClosed
                                        ? 'Phiên đã đóng — đang xem kết quả đã chốt. '
                                              'Không thể sửa Có / Vắng trên phiên này.'
                                        : 'Chưa có phiên đang mở — nhấn «Mở phiên» ở trên '
                                              'rồi mới chọn Có / Vắng.',
                                    style: TextStyle(
                                      color: _sessionClosed
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF9A3412),
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _StudentTile(
                            student: student,
                            status: _statusForStudent(student),
                            absentReason: _absentReasonForStudent(student),
                            pendingSync: _pendingSyncForStudent(student),
                            syncResult: marksByStudent[student.rosterStudentId]
                                ?.syncResult,
                            enabled: _canMark,
                            onStatusSelected: (status) =>
                                _handleManualStudentStatusSelected(
                                  student,
                                  status,
                                ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.session,
    required this.selectedTourName,
    required this.pendingCount,
    required this.conflictCount,
    required this.markedCount,
    required this.studentCount,
  });

  final AttendanceSessionDraft? session;
  final String? selectedTourName;
  final int pendingCount;
  final int conflictCount;
  final int markedCount;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    final startedAt = session?.startedAt;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session == null
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
                color: session == null
                    ? AppTheme.onSurfaceVariant
                    : AppTheme.accentGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session == null
                      ? 'Chưa mở phiên điểm danh'
                      : selectedTourName ?? 'Phiên đang mở',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (startedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Bắt đầu ${DateFormat('HH:mm dd/MM').format(startedAt.toLocal())}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Đã điểm danh',
                value: '$markedCount/$studentCount',
              ),
              _MetricChip(label: 'Chờ đồng bộ', value: '$pendingCount'),
              _MetricChip(label: 'Xung đột', value: '$conflictCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItinerarySessionBanner extends StatelessWidget {
  const _ItinerarySessionBanner({required this.sessionName});

  final String sessionName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill, color: AppTheme.accentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Phiên điểm danh đang mở theo lịch trình: $sessionName',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionModeBanner extends StatelessWidget {
  const _ConnectionModeBanner({
    required this.hasConnection,
    required this.pendingCount,
  });

  final bool hasConnection;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final color = hasConnection ? AppTheme.accentGreen : AppTheme.accentOrange;
    final message = hasConnection
        ? pendingCount > 0
              ? 'Đang online. Có $pendingCount bản ghi offline chờ đồng bộ.'
              : 'Đang online. Điểm danh thủ công cập nhật trực tiếp lên server.'
        : 'Thiết bị đang offline. Nhận diện khuôn mặt ngay trên máy, dữ liệu sẽ đồng bộ khi có mạng.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            hasConnection
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineFaceModeView extends StatelessWidget {
  const _OfflineFaceModeView({
    super.key,
    required this.faceService,
    required this.enabled,
    required this.processing,
    required this.activeSession,
    required this.templateCount,
    required this.student,
    required this.imageFile,
    required this.onCaptured,
    required this.onNext,
  });

  final MobileFaceEmbeddingService faceService;
  final bool enabled;
  final bool processing;
  final AttendanceSessionDraft? activeSession;
  final int templateCount;
  final AttendanceStudent? student;
  final XFile? imageFile;
  final void Function(XFile file, MobileFaceDetectionResult detection)
  onCaptured;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Panel(
          child: Row(
            children: [
              const Icon(Icons.offline_bolt_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeSession == null
                      ? 'Chọn tour đã tải roster và mẫu khuôn mặt trước đó, rồi mở phiên để quét offline.'
                      : 'Nhận diện ngay trên máy. Đã lưu $templateCount mẫu khuôn mặt.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (student == null)
          LiveFaceCapturePanel(
            faceService: faceService,
            pose: MobileFacePose.center,
            enabled: enabled,
            title: 'Khuôn mặt offline',
            subtitle:
                'Camera sẽ tự chụp khi có khuôn mặt ổn định, rồi so khớp trên máy.',
            onCaptured: onCaptured,
          ),
        if (processing) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (imageFile != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(File(imageFile!.path), fit: BoxFit.cover),
            ),
          ),
        ],
        if (student != null) ...[
          const SizedBox(height: 12),
          _StudentInfoPanel(student: student!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Quét học sinh tiếp theo'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentInfoPanel extends StatelessWidget {
  const _StudentInfoPanel({required this.student});

  final AttendanceStudent student;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (student.className != null && student.className!.trim().isNotEmpty)
        student.className!,
      if (student.studentCode != null && student.studentCode!.trim().isNotEmpty)
        student.studentCode!,
    ].join(' - ');
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceContainerHigh,
            child: Icon(Icons.person_outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.status,
    required this.absentReason,
    required this.pendingSync,
    required this.syncResult,
    required this.enabled,
    required this.onStatusSelected,
  });

  final AttendanceStudent student;
  final String status;
  final String? absentReason;
  final bool pendingSync;
  final String? syncResult;
  final bool enabled;
  final ValueChanged<String> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toUpperCase();
    final displayAbsentReason = normalizedStatus == 'ABSENT'
        ? absentReason?.trim()
        : null;
    final selected = normalizedStatus == 'PENDING'
        ? <String>{}
        : {normalizedStatus};
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceContainerHigh,
                child: Icon(Icons.person_outline, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (student.className != null) student.className!,
                        if (student.studentCode != null) student.studentCode!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: normalizedStatus),
            ],
          ),
          if (pendingSync) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Chờ đồng bộ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (syncResult != null) ...[
            const SizedBox(height: 8),
            _ConflictText(result: syncResult!),
          ],
          if (displayAbsentReason != null &&
              displayAbsentReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_outlined,
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lý do vắng: $displayAbsentReason',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              selected: selected,
              onSelectionChanged: enabled
                  ? (values) {
                      if (values.isNotEmpty) {
                        onStatusSelected(values.first);
                      }
                    }
                  : null,
              segments: const [
                ButtonSegment(
                  value: 'PRESENT',
                  icon: Icon(Icons.check_rounded),
                  label: Text('Có'),
                ),
                ButtonSegment(
                  value: 'ABSENT',
                  icon: Icon(Icons.close_rounded),
                  label: Text('Vắng'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PRESENT' => AppTheme.accentGreen,
      'ABSENT' => AppTheme.accentRed,
      'PENDING' => AppTheme.onSurfaceVariant,
      _ => AppTheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConflictText extends StatelessWidget {
  const _ConflictText({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: AppTheme.accentOrange),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            result,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.accentOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner._({
    required this.message,
    required this.icon,
    required this.color,
  });

  factory _Banner.success(String message) {
    return _Banner._(
      message: message,
      icon: Icons.check_circle_outline,
      color: AppTheme.accentGreen,
    );
  }

  factory _Banner.error(String message) {
    return _Banner._(
      message: message,
      icon: Icons.error_outline,
      color: AppTheme.accentRed,
    );
  }

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: SizedBox(
        height: 96,
        child: Center(child: Text('Chưa có roster trên máy.')),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (_normalizeAttendanceStatus(status)) {
    'PRESENT' => 'Có mặt',
    'ABSENT' => 'Vắng',
    'PENDING' => 'Chờ điểm danh',
    _ => status,
  };
}

String _normalizeAttendanceStatus(String status) {
  final normalized = status.toUpperCase();
  return normalized == 'LATE' ? 'ABSENT' : normalized;
}

String _sessionType(OfflineAttendanceMode mode) {
  return switch (mode) {
    OfflineAttendanceMode.face => 'FACE',
    OfflineAttendanceMode.manual => 'MANUAL',
  };
}

double? _cosineSimilarity(List<double> left, List<double> right) {
  if (left.isEmpty || left.length != right.length) return null;
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var i = 0; i < left.length; i++) {
    dot += left[i] * right[i];
    leftNorm += left[i] * left[i];
    rightNorm += right[i] * right[i];
  }
  if (leftNorm == 0 || rightNorm == 0) return null;
  return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
}

class _FaceTemplateMatch {
  const _FaceTemplateMatch({required this.template, required this.score});

  final OfflineFaceTemplate template;
  final double score;
}

String? _tourOrFirst(String? tourId, List<AttendanceTour> tours) {
  if (tourId != null && tours.any((tour) => tour.tourId == tourId)) {
    return tourId;
  }
  return tours.isEmpty ? null : tours.first.tourId;
}

String _friendlyError(Object error, {required String fallback}) {
  final apiException = ApiException.maybeFrom(error);
  final text = (apiException?.message ?? error.toString()).trim();
  if (text.trim().isEmpty) return fallback;
  final normalized = text.toLowerCase();
  if (normalized.contains('no face detected') ||
      normalized.contains('face not detected') ||
      normalized.contains('không phát hiện khuôn mặt')) {
    return 'Không phát hiện khuôn mặt trong ảnh điểm danh. Vui lòng đưa mặt học sinh vào khung rồi quét lại.';
  }
  if (_looksOffline(error)) {
    return '$fallback Kiểm tra mạng rồi thử sync lại.';
  }
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
      .split('\n')
      .first
      .trim();
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

String? _planItemOrFirst(
  String? planItemId,
  List<AttendanceCheckpoint> checkpoints,
) {
  if (planItemId != null &&
      checkpoints.any((checkpoint) => checkpoint.planItemId == planItemId)) {
    return planItemId;
  }
  return checkpoints.isEmpty ? null : checkpoints.first.planItemId;
}

String? _vehicleOrFirst(String? vehicleId, List<AttendanceStudent> students) {
  final ids = students
      .map((student) => student.operationVehicleId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
  if (vehicleId != null && ids.contains(vehicleId)) {
    return vehicleId;
  }
  return ids.isEmpty ? null : ids.first;
}

class _AbsentReasonDialog extends StatefulWidget {
  const _AbsentReasonDialog({required this.studentName});

  final String studentName;

  @override
  State<_AbsentReasonDialog> createState() => _AbsentReasonDialogState();
}

class _AbsentReasonDialogState extends State<_AbsentReasonDialog> {
  late final TextEditingController _controller;
  var _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lý do vắng mặt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhập lý do vắng mặt cho ${widget.studentName}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Lý do',
              hintText: 'Ví dụ: Phụ huynh báo nghỉ, đến muộn...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final nextCanSubmit = value.trim().isNotEmpty;
              if (nextCanSubmit != _canSubmit) {
                setState(() => _canSubmit = nextCanSubmit);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('Lưu lý do'),
        ),
      ],
    );
  }
}
