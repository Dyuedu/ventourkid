import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../features/attendance/domain/entities/offline_attendance.dart';
import '../../../../features/attendance/presentation/widgets/pre_trip_checklist_view.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../data/services/mobile_face_embedding_service.dart';
import '../../domain/entities/mobile_face_embedding.dart';
import '../widgets/live_face_capture_panel.dart';

class FaceAttendancePage extends ConsumerStatefulWidget {
  const FaceAttendancePage({
    super.key,
    this.initialTourId,
    this.initialCheckpointId,
    this.initialVehicleId,
    this.initialTourName,
    this.initialCheckpointLabel,
    this.initialVehicleLabel,
  });

  final String? initialTourId;
  final String? initialCheckpointId;
  final String? initialVehicleId;
  final String? initialTourName;
  final String? initialCheckpointLabel;
  final String? initialVehicleLabel;

  @override
  ConsumerState<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends ConsumerState<FaceAttendancePage> {
  static const String _outOfVehicleAttendanceMessage =
      'Học sinh được nhận diện không thuộc xe đang điểm danh. Vui lòng chọn đúng xe hoặc quét học sinh trong xe này.';

  List<AttendanceTour> _tours = const [];
  List<AttendanceCheckpoint> _checkpoints = const [];
  List<AttendanceStudent> _students = const [];
  List<AttendanceSessionSummary> _sessions = const [];
  AttendanceSessionDraft? _activeSession;
  PreTripChecklist? _preTripChecklist;
  String? _userRole;
  String? _selectedTourId;
  String? _selectedCheckpointId;
  String? _selectedVehicleId;
  String _tourDisplayName = '';
  String _checkpointDisplayLabel = '';
  String _vehicleDisplayLabel = '';
  int _selectionEpoch = 0;
  XFile? _capturedFile;
  bool _loadingTours = true;
  bool _loadingCheckpoints = false;
  bool _loadingStudents = false;
  bool _checkingPreTrip = false;
  bool _savingPreTrip = false;
  bool _showPreTripChecklist = false;
  bool _processing = false;
  int _scanRound = 0;
  String? _message;
  String? _error;
  FaceAttendanceCaptureResult? _attendanceResult;

  @override
  void initState() {
    super.initState();
    _tourDisplayName = widget.initialTourName?.trim() ?? '';
    _checkpointDisplayLabel = widget.initialCheckpointLabel?.trim() ?? '';
    _vehicleDisplayLabel = widget.initialVehicleLabel?.trim() ?? '';
    _selectedTourId = widget.initialTourId;
    _selectedCheckpointId = widget.initialCheckpointId;
    _selectedVehicleId = widget.initialVehicleId;
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    if ((widget.initialTourId ?? '').isEmpty ||
        (widget.initialCheckpointId ?? '').isEmpty ||
        (widget.initialVehicleId ?? '').isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingTours = false;
        _error =
            'Chưa có thông tin phiên điểm danh. Quay lại tab thủ công để chọn tour, lịch và xe trước.';
      });
      return;
    }
    final role = (await ref.read(routeGuardsProvider).userRole)?.toUpperCase();
    if (!mounted) return;
    setState(() => _userRole = role);
    if (_requiresTeacherPreTripChecklist) {
      await _loadTeacherPreTripChecklistGate(loadAttendanceWhenConfirmed: true);
      return;
    }
    await _loadTours();
  }

  bool get _requiresTeacherPreTripChecklist => _userRole == 'TEACHER';

  Future<void> _loadTeacherPreTripChecklistGate({
    bool loadAttendanceWhenConfirmed = false,
  }) async {
    final tourId = _selectedTourId ?? widget.initialTourId;
    if (tourId == null || tourId.isEmpty) {
      await _loadTours();
      return;
    }
    setState(() {
      _checkingPreTrip = true;
      _loadingTours = true;
      _error = null;
    });
    try {
      final checklist = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getPreTripChecklist(tourId);
      if (!mounted) return;
      setState(() {
        _preTripChecklist = checklist;
        _showPreTripChecklist = !checklist.confirmed;
        _checkingPreTrip = false;
        _loadingTours = !checklist.confirmed;
      });
      if (checklist.confirmed &&
          (loadAttendanceWhenConfirmed ||
              _tours.isEmpty ||
              _selectedTour == null)) {
        await _loadTours();
      } else if (!checklist.confirmed) {
        setState(() => _loadingTours = false);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingPreTrip = false;
        _loadingTours = false;
        _error = _friendlyError(
          error,
          fallback: 'Chưa tải được checklist trước chuyến.',
        );
      });
    }
  }

  void _updatePreTripItem(String itemId, {bool? checked, String? note}) {
    final checklist = _preTripChecklist;
    if (checklist == null) return;
    setState(() {
      _preTripChecklist = checklist.copyWith(
        confirmed: checklist.confirmed && checked != false,
        items: checklist.items
            .map(
              (item) => item.id == itemId
                  ? item.copyWith(checked: checked, note: note)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<void> _savePreTripChecklist({required bool confirm}) async {
    final checklist = _preTripChecklist;
    final tourId = _selectedTourId ?? widget.initialTourId;
    if (checklist == null ||
        tourId == null ||
        tourId.isEmpty ||
        _savingPreTrip) {
      return;
    }
    if (confirm && !checklist.requiredItemsDone) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng tick đủ các mục bắt buộc trước khi điểm danh khuôn mặt.',
            ),
          ),
        );
      return;
    }

    setState(() => _savingPreTrip = true);
    try {
      final updated = await ref
          .read(offlineAttendanceRepositoryProvider)
          .updatePreTripChecklist(
            tourId: tourId,
            items: checklist.items,
            confirm: confirm,
          );
      if (!mounted) return;
      setState(() {
        _preTripChecklist = updated;
        _showPreTripChecklist = confirm ? !updated.confirmed : true;
      });
      if (confirm && updated.confirmed) {
        if (_tours.isEmpty || _selectedTour == null) {
          await _loadTours();
        } else {
          await _reloadRoster();
        }
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _friendlyError(
                error,
                fallback: 'Chưa lưu được checklist trước chuyến.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _savingPreTrip = false);
      }
    }
  }

  void _openPreTripChecklist() {
    if (!_requiresTeacherPreTripChecklist) return;
    if (_preTripChecklist == null || _checkingPreTrip) {
      Future.microtask(_loadTeacherPreTripChecklistGate);
      return;
    }
    setState(() => _showPreTripChecklist = true);
  }

  Future<void> _reloadRoster() async {
    final tourId = _selectedTourId;
    if (tourId == null || tourId.isEmpty) return;
    final epoch = ++_selectionEpoch;
    await Future.wait([
      _loadStudents(tourId, refresh: true, epoch: epoch),
      _loadSessions(tourId, epoch: epoch),
    ]);
    if (!mounted || epoch != _selectionEpoch) return;
    await _syncActiveSessionForSelection(epoch: epoch);
  }

  Future<void> _loadTours() async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    setState(() {
      _loadingTours = true;
      _error = null;
    });

    try {
      final activeSession = await repository.getActiveSession();
      final tours = await repository.refreshTours();
      if (!mounted) return;
      final selectedTourId = _tourOrFirst(
        _selectedTourId ?? activeSession?.tourId ?? widget.initialTourId,
        tours,
      );
      setState(() {
        _activeSession = activeSession;
        _tours = tours;
        _selectedTourId = selectedTourId;
        _selectedCheckpointId ??=
            widget.initialCheckpointId ?? activeSession?.checkpointId;
        _selectedVehicleId =
            widget.initialVehicleId ??
            activeSession?.operationVehicleId ??
            _selectedVehicleId;
        _resolveDisplayLabels();
        _message = null;
      });
      if (selectedTourId != null) {
        await _selectTour(selectedTourId, refresh: true);
      }
    } on Object catch (error) {
      final activeSession = await repository.getActiveSession();
      final cachedTours = await repository.getCachedTours();
      if (!mounted) return;
      final selectedTourId = _tourOrFirst(
        _selectedTourId ?? activeSession?.tourId ?? widget.initialTourId,
        cachedTours,
      );
      setState(() {
        _activeSession = activeSession;
        _tours = cachedTours;
        _selectedTourId = selectedTourId;
        _selectedCheckpointId ??=
            widget.initialCheckpointId ?? activeSession?.checkpointId;
        _selectedVehicleId =
            widget.initialVehicleId ??
            activeSession?.operationVehicleId ??
            _selectedVehicleId;
        _resolveDisplayLabels();
        _message = cachedTours.isNotEmpty
            ? 'Đang dùng danh sách tour đã lưu trên máy.'
            : null;
        _error = cachedTours.isEmpty
            ? _friendlyError(
                error,
                fallback: 'Chưa tải được tour đang quản lý.',
              )
            : null;
      });
      if (selectedTourId != null) {
        await _selectTour(selectedTourId, refresh: false);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTours = false);
      }
    }
  }

  Future<void> _selectTour(String tourId, {required bool refresh}) async {
    final epoch = ++_selectionEpoch;
    await Future.wait([
      _loadCheckpoints(tourId, refresh: refresh, epoch: epoch),
      _loadStudents(tourId, refresh: refresh, epoch: epoch),
      _loadSessions(tourId, epoch: epoch),
    ]);
    if (!mounted || epoch != _selectionEpoch) return;
    await _syncActiveSessionForSelection(epoch: epoch);
  }

  void _resolveDisplayLabels() {
    final tour = _selectedTour;
    if (_tourDisplayName.isEmpty && tour != null) {
      _tourDisplayName = tour.tourName;
    }

    if (_checkpointDisplayLabel.isEmpty && _selectedCheckpointId != null) {
      final checkpoint = _checkpoints
          .where((item) => item.checkpointId == _selectedCheckpointId)
          .firstOrNull;
      if (checkpoint != null) {
        _checkpointDisplayLabel =
            '${checkpoint.sortOrder + 1}. ${checkpoint.name} (${checkpoint.kind})';
      }
    }

    if (_vehicleDisplayLabel.isEmpty && _selectedVehicleId != null) {
      final vehicleId = _selectedVehicleId!;
      if (vehicleId.isNotEmpty) {
        _vehicleDisplayLabel = vehicleId.length >= 8
            ? 'Xe ${vehicleId.substring(0, 8)}'
            : 'Xe $vehicleId';
      }
    }
  }

  Future<void> _loadSessions(String tourId, {required int epoch}) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    try {
      final sessions = await repository.refreshSessions(tourId);
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() => _sessions = sessions);
    } on Object {
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() => _sessions = const []);
    }
  }

  Future<void> _syncActiveSessionForSelection({required int epoch}) async {
    final tourId = _selectedTourId;
    final checkpointId = _selectedCheckpointId;
    if (tourId == null || checkpointId == null || checkpointId.isEmpty) {
      return;
    }

    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final localSession = await repository.getActiveSession();
    if (!mounted || epoch != _selectionEpoch) return;

    final checkpoint = _checkpoints
        .where((item) => item.checkpointId == checkpointId)
        .firstOrNull;
    final openSession = _sessions
        .where(
          (session) =>
              session.checkpointId == checkpointId &&
              session.status.toUpperCase() == 'OPEN',
        )
        .firstOrNull;

    AttendanceSessionDraft? session;
    if (openSession != null) {
      session = AttendanceSessionDraft(
        sessionId: openSession.sessionId,
        planItemId: checkpoint?.planItemId ?? '',
        tourId: tourId,
        checkpointId: checkpointId,
        operationVehicleId: _selectedVehicleId ?? '',
        status: openSession.status,
        studentCount: _studentsForVehicle.length,
        startedAt: openSession.startedAt ?? DateTime.now().toUtc(),
        sessionName: openSession.sessionName,
        sessionType: openSession.sessionType,
      );
    } else if (localSession != null &&
        localSession.tourId == tourId &&
        localSession.checkpointId == checkpointId) {
      session = localSession;
      if ((_selectedVehicleId ?? '').isEmpty &&
          localSession.operationVehicleId.isNotEmpty) {
        _selectedVehicleId = localSession.operationVehicleId;
      }
    }

    if (!mounted || epoch != _selectionEpoch) return;
    setState(() => _activeSession = session);
  }

  Future<void> _loadCheckpoints(
    String tourId, {
    required bool refresh,
    required int epoch,
  }) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final previousTourId = _selectedTourId;
    setState(() {
      _loadingCheckpoints = true;
      _selectedTourId = tourId;
      _selectedCheckpointId = previousTourId == tourId
          ? _selectedCheckpointId
          : (_activeSession?.tourId == tourId
                ? _activeSession?.checkpointId
                : widget.initialCheckpointId);
      if (previousTourId != tourId) {
        _checkpoints = const [];
      }
      _error = null;
      _attendanceResult = null;
      _capturedFile = null;
      _scanRound += 1;
    });

    final cachedCheckpoints = await repository.getCachedCheckpoints(tourId);
    if (mounted && epoch == _selectionEpoch && cachedCheckpoints.isNotEmpty) {
      setState(() {
        _checkpoints = cachedCheckpoints;
        _selectedCheckpointId = _checkpointOrFirst(
          _selectedCheckpointId ??
              widget.initialCheckpointId ??
              (_activeSession?.tourId == tourId
                  ? _activeSession?.checkpointId
                  : null),
          cachedCheckpoints,
        );
        _resolveDisplayLabels();
      });
    }

    if (!refresh) {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _loadingCheckpoints = false);
      }
      return;
    }

    try {
      final checkpoints = await repository.refreshCheckpoints(tourId);
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() {
        _checkpoints = checkpoints;
        _selectedCheckpointId = _checkpointOrFirst(
          _selectedCheckpointId ??
              widget.initialCheckpointId ??
              (_activeSession?.tourId == tourId
                  ? _activeSession?.checkpointId
                  : null),
          checkpoints,
        );
        _resolveDisplayLabels();
      });
    } on Object catch (error) {
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() {
        _message = cachedCheckpoints.isNotEmpty
            ? 'Đang dùng checkpoint đã lưu trên máy.'
            : _message;
        _error = cachedCheckpoints.isEmpty
            ? _friendlyError(error, fallback: 'Chưa tải được checkpoint.')
            : null;
      });
    } finally {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _loadingCheckpoints = false);
      }
    }
  }

  Future<void> _loadStudents(
    String tourId, {
    required bool refresh,
    required int epoch,
  }) async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final vehicleId = _selectedVehicleId;
    setState(() {
      _loadingStudents = true;
      _selectedTourId = tourId;
      if (refresh) {
        _students = const [];
      }
      _error = null;
    });

    final cachedStudents = await repository.getCachedStudents(
      tourId,
      operationVehicleId: vehicleId,
    );
    if (mounted && epoch == _selectionEpoch && cachedStudents.isNotEmpty) {
      setState(() {
        _students = cachedStudents;
        _selectedVehicleId = _vehicleOrFirst(
          _selectedVehicleId,
          cachedStudents,
        );
      });
    }

    if (!refresh) {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _loadingStudents = false);
      }
      return;
    }

    try {
      final students = await repository.refreshStudents(
        tourId,
        operationVehicleId: vehicleId,
      );
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() {
        _students = students;
        _selectedVehicleId = _vehicleOrFirst(_selectedVehicleId, students);
        _message = 'Đã tải roster ${students.length} học sinh.';
      });
    } on Object catch (error) {
      if (!mounted || epoch != _selectionEpoch) return;
      setState(() {
        _message = cachedStudents.isNotEmpty
            ? 'Đang dùng roster đã lưu trên máy.'
            : _message;
        _error = cachedStudents.isEmpty
            ? _friendlyError(error, fallback: 'Chưa tải được roster.')
            : null;
      });
    } finally {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _loadingStudents = false);
      }
    }
  }

  Future<void> _onAutoCaptured(
    XFile file,
    MobileFaceDetectionResult detection,
  ) async {
    if (!mounted || _processing) return;
    await _submitCaptured(file);
  }

  Future<void> _submitCaptured(XFile file) async {
    final tour = _selectedTour;
    final checkpointId = _selectedCheckpointId;
    if (tour == null) {
      _setError('Thiếu thông tin tour. Quay lại tab thủ công để chọn lại.');
      await _deleteQuietly(file.path);
      return;
    }
    if (checkpointId == null || checkpointId.isEmpty) {
      _setError(
        'Thiếu thông tin checkpoint. Quay lại tab thủ công để chọn lại.',
      );
      await _deleteQuietly(file.path);
      return;
    }

    setState(() {
      _processing = true;
      _capturedFile = file;
      _message =
          'Đã phát hiện khuôn mặt. Đang tạo mã nhận diện trên thiết bị...';
      _error = null;
      _attendanceResult = null;
    });

    try {
      final result = await _captureAttendance(file, tour, checkpointId);
      if (!mounted) return;
      final matchedStudent = _studentForResult(result);
      final recognized = _isAttendanceAccepted(result);
      final accepted = recognized && matchedStudent != null;
      final errorMessage = recognized && matchedStudent == null
          ? _outOfVehicleAttendanceMessage
          : _attendanceResultMessage(result);
      setState(() {
        _attendanceResult = accepted ? result : null;
        _message = accepted
            ? '${matchedStudent.fullName}${matchedStudent.className == null ? '' : ' - lớp ${matchedStudent.className}'} đã quét thành công. Chuẩn bị quét học sinh tiếp theo.'
            : null;
        _error = accepted ? null : errorMessage;
        if (!accepted) {
          _capturedFile = null;
          _scanRound += 1;
        }
      });
      if (accepted) {
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && !_processing) {
            _resetScan();
          }
        });
      }
      if (!accepted) {
        await _deleteQuietly(file.path);
      }
    } on Object catch (error) {
      if (!mounted) return;
      if (_looksOffline(error)) {
        await _deleteQuietly(file.path);
        await _switchToOfflineFaceAttendance();
        return;
      }
      _setError(_friendlyError(error, fallback: 'Chưa điểm danh được.'));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<FaceAttendanceCaptureResult> _captureAttendance(
    XFile file,
    AttendanceTour tour,
    String checkpointId,
  ) async {
    final faceRemote = ref.read(faceRemoteDataSourceProvider);
    final activeSessionId = _activeServerSessionId;
    if (Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _message = 'Đang gửi ảnh lên InsightFace để xác thực...';
        });
      }
      return await faceRemote.captureAttendanceImage(
        tourId: tour.tourId,
        schoolId: tour.schoolId,
        checkpointId: checkpointId,
        attendanceSessionId: activeSessionId,
        imagePath: file.path,
        topK: 1,
      );
    }
    try {
      final face = await ref
          .read(mobileFaceEmbeddingServiceProvider)
          .createEmbedding(file.path);
      if (mounted) {
        setState(() {
          _message = 'Đang đối chiếu khuôn mặt với roster...';
        });
      }
      return await faceRemote.captureAttendance(
        tourId: tour.tourId,
        schoolId: tour.schoolId,
        checkpointId: checkpointId,
        attendanceSessionId: activeSessionId,
        face: face,
        topK: 1,
      );
    } on Object catch (error) {
      if (!_shouldFallbackToImageCapture(error)) {
        rethrow;
      }
      if (mounted) {
        setState(() {
          _message = 'Đang gửi ảnh lên InsightFace để xác thực...';
        });
      }
      return await faceRemote.captureAttendanceImage(
        tourId: tour.tourId,
        schoolId: tour.schoolId,
        checkpointId: checkpointId,
        attendanceSessionId: activeSessionId,
        imagePath: file.path,
        topK: 1,
      );
    }
  }

  Future<void> _switchToOfflineFaceAttendance() async {
    final tourId = _selectedTourId ?? widget.initialTourId;
    final checkpointId = _selectedCheckpointId ?? widget.initialCheckpointId;
    final vehicleId = _selectedVehicleId ?? widget.initialVehicleId;
    final planItemId = _activeSession?.planItemId.isNotEmpty == true
        ? _activeSession!.planItemId
        : _checkpoints
              .where((checkpoint) => checkpoint.checkpointId == checkpointId)
              .firstOrNull
              ?.planItemId;

    if (tourId == null ||
        tourId.isEmpty ||
        checkpointId == null ||
        checkpointId.isEmpty ||
        vehicleId == null ||
        vehicleId.isEmpty ||
        planItemId == null ||
        planItemId.isEmpty) {
      _setError(
        'Thiết bị mất mạng nhưng chưa đủ dữ liệu cache để chuyển sang điểm danh offline.',
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Thiết bị mất mạng. Đang chuyển sang điểm danh khuôn mặt offline.',
          ),
        ),
      );
    context.pushReplacement(
      Uri(
        path: '/attendance/offline',
        queryParameters: {
          'tourId': tourId,
          'planItemId': planItemId,
          'checkpointId': checkpointId,
          'vehicleId': vehicleId,
          'mode': 'face',
          'autoStart': 'true',
          'fromItinerary': 'true',
          if ((_activeSession?.sessionName ?? '').trim().isNotEmpty)
            'sessionName': _activeSession!.sessionName!.trim(),
        },
      ).toString(),
    );
  }

  Future<void> _resetScan() async {
    final oldFile = _capturedFile;
    if (oldFile != null) {
      await _deleteQuietly(oldFile.path);
    }
    if (!mounted) return;
    setState(() {
      _capturedFile = null;
      _attendanceResult = null;
      _error = null;
      _message = null;
      _scanRound += 1;
    });
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  AttendanceTour? get _selectedTour {
    for (final tour in _tours) {
      if (tour.tourId == _selectedTourId) return tour;
    }
    return null;
  }

  String? get _activeServerSessionId {
    final session = _activeSession;
    if (session == null ||
        session.sessionId.isEmpty ||
        session.sessionId.startsWith('local-') ||
        session.tourId != _selectedTourId ||
        session.checkpointId != _selectedCheckpointId) {
      return null;
    }
    return session.sessionId;
  }

  AttendanceStudent? _studentForResult(FaceAttendanceCaptureResult? result) {
    if (result == null) return null;
    final ids = <String>{
      if (result.detectedStudentId != null) result.detectedStudentId!,
      for (final candidate in result.candidates) ...[
        if (candidate.rosterStudentId != null) candidate.rosterStudentId!,
        candidate.studentId,
      ],
    }.where((id) => id.trim().isNotEmpty).toSet();

    for (final student in _studentsForVehicle) {
      if (ids.contains(student.rosterStudentId)) return student;
    }
    return null;
  }

  bool _isAttendanceAccepted(FaceAttendanceCaptureResult result) {
    final value = result.result.toUpperCase();
    return value == 'MATCHED' ||
        (value == 'LOW_CONFIDENCE' && result.confidence >= 0.60);
  }

  String _attendanceResultMessage(FaceAttendanceCaptureResult result) {
    final value = result.result.toUpperCase();
    if (value == 'OUT_OF_VEHICLE') {
      return _outOfVehicleAttendanceMessage;
    }
    if (value == 'LOW_CONFIDENCE') {
      return 'Khuôn mặt gần giống học sinh trong roster nhưng chưa đủ chắc chắn để điểm danh. Vui lòng quét lại với mặt rõ hơn.';
    }
    if (value == 'NOT_MATCHED') {
      return 'Chưa tìm thấy học sinh phù hợp trong roster của tour này.';
    }
    return 'Chưa điểm danh được. Vui lòng quét lại.';
  }

  void _setError(String message) {
    setState(() {
      _error = message;
      _message = null;
      _processing = false;
    });
  }

  List<AttendanceStudent> get _studentsForVehicle {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return _students;
    return _students
        .where((student) => student.operationVehicleId == vehicleId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final showTeacherChecklist =
        _requiresTeacherPreTripChecklist &&
        _showPreTripChecklist &&
        _preTripChecklist != null;
    final canScan =
        !showTeacherChecklist &&
        !_checkingPreTrip &&
        !_loadingTours &&
        !_loadingCheckpoints &&
        !_loadingStudents &&
        !_processing &&
        _selectedTour != null &&
        _selectedCheckpointId != null &&
        _attendanceResult == null;
    final matchedStudent = _studentForResult(_attendanceResult);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text('Điểm danh khuôn mặt'),
        actions: [
          if (_requiresTeacherPreTripChecklist)
            IconButton(
              tooltip: 'Checklist trước chuyến',
              onPressed: _checkingPreTrip || _processing
                  ? null
                  : _openPreTripChecklist,
              icon: const Icon(Icons.fact_check_outlined),
            ),
          IconButton(
            tooltip: 'Trợ lý AI',
            onPressed: () => context.push('/ai-assistant'),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: 'Tải lại roster',
            onPressed: _loadingStudents || _checkingPreTrip || _processing
                ? null
                : (_requiresTeacherPreTripChecklist && _showPreTripChecklist
                      ? _loadTeacherPreTripChecklistGate
                      : _reloadRoster),
            icon: _loadingStudents
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _checkingPreTrip
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : showTeacherChecklist
                ? PreTripChecklistView(
                    checklist: _preTripChecklist!,
                    saving: _savingPreTrip,
                    onChanged: _updatePreTripItem,
                    onSaveDraft: () => _savePreTripChecklist(confirm: false),
                    onConfirm: () => _savePreTripChecklist(confirm: true),
                    onBack: _preTripChecklist!.confirmed
                        ? () => setState(() => _showPreTripChecklist = false)
                        : null,
                    backLabel: 'Quay lại điểm danh',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _AttendanceContextPanel(
                        tourLabel: _tourDisplayName,
                        checkpointLabel: _checkpointDisplayLabel,
                        vehicleLabel: _vehicleDisplayLabel,
                        loadingCheckpoints: _loadingCheckpoints,
                      ),
                      const SizedBox(height: 16),
                      if (_attendanceResult == null && !_processing)
                        LiveFaceCapturePanel(
                          key: ValueKey('attendance-$_scanRound'),
                          faceService: ref.watch(
                            mobileFaceEmbeddingServiceProvider,
                          ),
                          pose: MobileFacePose.center,
                          enabled: canScan,
                          normalizeCapture: !Platform.isAndroid,
                          title: 'Tự quét khuôn mặt',
                          subtitle:
                              'Đưa một học sinh vào khung. ML Kit tự chụp khi mặt ổn định, backend sẽ gọi InsightFace để nhận diện.',
                          onCaptured: _onAutoCaptured,
                        ),
                      if (_processing) ...[
                        const SizedBox(height: 12),
                        _ProcessingStatusCard(message: _message),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (_loadingStudents) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_capturedFile != null && !_processing) ...[
                        const SizedBox(height: 12),
                        _CapturedImagePreview(file: _capturedFile!),
                      ],
                      const SizedBox(height: 16),
                      if (_message != null && !_processing)
                        _ResultBanner.success(_message!),
                      if (_error != null) _ResultBanner.error(_error!),
                      if (_attendanceResult != null) ...[
                        _AttendanceResultView(student: matchedStudent),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _resetScan,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Quét học sinh tiếp theo'),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceContextPanel extends StatelessWidget {
  const _AttendanceContextPanel({
    required this.tourLabel,
    required this.checkpointLabel,
    required this.vehicleLabel,
    required this.loadingCheckpoints,
  });

  final String tourLabel;
  final String checkpointLabel;
  final String vehicleLabel;
  final bool loadingCheckpoints;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _ReadOnlyContextField(
              label: 'Tour',
              value: tourLabel,
              icon: Icons.route_outlined,
            ),
            const SizedBox(height: 10),
            _ReadOnlyContextField(
              label: 'Lịch điểm danh',
              value: checkpointLabel,
              icon: Icons.place_outlined,
              loading: loadingCheckpoints,
            ),
            const SizedBox(height: 10),
            _ReadOnlyContextField(
              label: 'Xe điểm danh',
              value: vehicleLabel,
              icon: Icons.directions_bus_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyContextField extends StatelessWidget {
  const _ReadOnlyContextField({
    required this.label,
    required this.value,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayValue = value.trim().isEmpty ? '—' : value.trim();

    return IgnorePointer(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(icon),
          enabled: false,
        ),
        child: Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            color: textTheme.bodyLarge?.color?.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _ProcessingStatusCard extends StatelessWidget {
  const _ProcessingStatusCard({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Đang xử lý ảnh điểm danh...',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturedImagePreview extends StatelessWidget {
  const _CapturedImagePreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.file(File(file.path), fit: BoxFit.cover),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner._({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  factory _ResultBanner.success(String message) {
    return _ResultBanner._(
      message: message,
      backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.12),
      foregroundColor: AppTheme.accentGreen,
      icon: Icons.check_circle_outline,
    );
  }

  factory _ResultBanner.error(String message) {
    return _ResultBanner._(
      message: message,
      backgroundColor: AppTheme.errorContainer.withValues(alpha: 0.36),
      foregroundColor: AppTheme.accentRed,
      icon: Icons.error_outline,
    );
  }

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceResultView extends StatelessWidget {
  const _AttendanceResultView({required this.student});

  final AttendanceStudent? student;

  @override
  Widget build(BuildContext context) {
    final matchedStudent = student;
    if (matchedStudent == null) {
      return const _ResultDetails(rows: {'Trạng thái': 'Điểm danh thành công'});
    }

    return _ResultDetails(
      rows: {
        'Họ tên': matchedStudent.fullName,
        if (_hasText(matchedStudent.studentCode))
          'Mã học sinh': matchedStudent.studentCode!,
        if (_hasText(matchedStudent.className))
          'Lớp': matchedStudent.className!,
        if (_hasText(matchedStudent.gender))
          'Giới tính': matchedStudent.gender!,
        if (matchedStudent.dateOfBirth != null)
          'Ngày sinh': _formatDate(matchedStudent.dateOfBirth!),
      },
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: rows.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

String? _vehicleOrFirst(String? vehicleId, List<AttendanceStudent> students) {
  if (vehicleId != null &&
      students.any((student) => student.operationVehicleId == vehicleId)) {
    return vehicleId;
  }
  for (final student in students) {
    final id = student.operationVehicleId;
    if (id != null && id.isNotEmpty) return id;
  }
  return vehicleId;
}

String? _tourOrFirst(String? tourId, List<AttendanceTour> tours) {
  if (tourId != null && tours.any((tour) => tour.tourId == tourId)) {
    return tourId;
  }
  return tours.isEmpty ? null : tours.first.tourId;
}

String? _checkpointOrFirst(
  String? checkpointId,
  List<AttendanceCheckpoint> checkpoints,
) {
  if (checkpointId != null &&
      checkpoints.any(
        (checkpoint) => checkpoint.checkpointId == checkpointId,
      )) {
    return checkpointId;
  }
  return checkpoints.isEmpty ? null : checkpoints.first.checkpointId;
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
  if (normalized.contains('landmarks are incomplete') ||
      normalized.contains('unable to align face') ||
      normalized.contains('không đọc được ảnh khuôn mặt')) {
    return 'Khuôn mặt chưa đủ rõ để tạo mã nhận diện. Vui lòng nhìn thẳng, giữ mặt trong khung rồi quét lại.';
  }
  if (normalized.contains('insightface') ||
      normalized.contains('dịch vụ insightface')) {
    return 'InsightFace chưa xử lý được ảnh điểm danh. Vui lòng thử lại, hoặc chuyển sang điểm danh thủ công nếu cần.';
  }

  if (normalized.contains('socketexception') ||
      normalized.contains('connection') ||
      normalized.contains('timed out') ||
      normalized.contains('failed host lookup')) {
    return '$fallback Kiểm tra mạng rồi thử lại.';
  }

  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
      .split('\n')
      .first
      .trim();
}

bool _shouldFallbackToImageCapture(Object error) {
  if (error is MobileFaceEmbeddingException) {
    return true;
  }
  final normalized = error.toString().toLowerCase();
  return normalized.contains('onnx') ||
      normalized.contains('landmark') ||
      normalized.contains('align face') ||
      normalized.contains('embedding');
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
