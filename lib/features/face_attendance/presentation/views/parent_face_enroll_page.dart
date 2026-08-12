import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../data/services/mobile_face_embedding_service.dart';
import '../../domain/entities/mobile_face_embedding.dart';
import '../widgets/live_face_capture_panel.dart';

class ParentFaceEnrollPage extends ConsumerStatefulWidget {
  const ParentFaceEnrollPage({
    super.key,
    required this.studentId,
    required this.schoolId,
    required this.operationPlanId,
    this.studentName,
    this.consentRecordId,
  });

  final String studentId;
  final String schoolId;
  final String operationPlanId;
  final String? studentName;
  final String? consentRecordId;

  @override
  ConsumerState<ParentFaceEnrollPage> createState() =>
      _ParentFaceEnrollPageState();
}

class _ParentFaceEnrollPageState extends ConsumerState<ParentFaceEnrollPage> {
  static const _poses = <MobileFacePose>[
    MobileFacePose.center,
    MobileFacePose.right,
    MobileFacePose.left,
    MobileFacePose.up,
    MobileFacePose.down,
  ];

  final Map<MobileFacePose, XFile> _captures = {};
  int _poseIndex = 0;
  bool _saving = false;
  String? _error;
  FaceEnrollmentResult? _result;

  MobileFacePose get _activePose => _poses[_poseIndex];

  Future<void> _onCaptured(
    XFile file,
    MobileFaceDetectionResult detection,
  ) async {
    if (!mounted || _saving || _result != null) return;
    setState(() {
      _captures[_activePose] = file;
      _error = null;
    });

    if (_captures.length == _poses.length) {
      await _submitMultiAngle();
      return;
    }

    setState(() {
      _poseIndex = (_poseIndex + 1).clamp(0, _poses.length - 1).toInt();
    });
  }

  Future<void> _submitMultiAngle() async {
    if (_saving) return;
    final missing = _poses
        .where((pose) => !_captures.containsKey(pose))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Cần chụp đủ 5 góc mặt trước khi lưu.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.operationPlanId.trim().isEmpty) {
        throw StateError(
          'Chưa xác định được tour để cấp quyền điểm danh khuôn mặt.',
        );
      }
      final faceRemote = ref.read(faceRemoteDataSourceProvider);
      final role = await ref.read(routeGuardsProvider).userRole;
      if (role != 'TEACHER') {
        await faceRemote.authorizeFaceAttendance(
          studentId: widget.studentId,
          operationPlanId: widget.operationPlanId,
        );
      }
      final result = await faceRemote.enrollMultiAngle(
        studentId: widget.studentId,
        schoolId: widget.schoolId,
        imagePathsByPose: {
          for (final entry in _captures.entries)
            _poseRequestKey(entry.key): entry.value.path,
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _reset() async {
    for (final file in _captures.values) {
      await _deleteQuietly(file.path);
    }
    if (!mounted) return;
    setState(() {
      _captures.clear();
      _poseIndex = 0;
      _saving = false;
      _error = null;
      _result = null;
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

  @override
  Widget build(BuildContext context) {
    final name = widget.studentName ?? 'Học sinh';
    final activeLabel = _poseLabel(_activePose);
    final progress = _captures.length / _poses.length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/parent/dashboard',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đăng ký khuôn mặt',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProgressHeader(
                  capturedCount: _captures.length,
                  totalCount: _poses.length,
                  activePose: activeLabel,
                  progress: progress,
                ),
                const SizedBox(height: 12),
                if (_result == null)
                  LiveFaceCapturePanel(
                    key: ValueKey(
                      'enroll-${_activePose.name}-${_captures.length}',
                    ),
                    faceService: ref.watch(mobileFaceEmbeddingServiceProvider),
                    pose: _activePose,
                    enabled: !_saving,
                    requiredStableFrames: 1,
                    scanInterval: const Duration(milliseconds: 900),
                    relaxedDetection: true,
                    title: 'Góc $activeLabel',
                    subtitle: _poseHint(_activePose),
                    onCaptured: _onCaptured,
                  )
                else
                  _SuccessPanel(
                    result: _result!,
                    studentName: name,
                    onDone: () => Navigator.of(context).pop(true),
                    onReset: _reset,
                  ),
                const SizedBox(height: 12),
                _CapturePreviewGrid(captures: _captures),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  ParentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          'Đang lưu 5 góc mặt và tạo vector điểm danh...',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ParentBanner(
                    icon: Icons.error_outline,
                    tone: ParentBannerTone.danger,
                    text: _error!,
                  ),
                ],
                const SizedBox(height: 12),
                if (_result == null)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _reset,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Chụp lại từ đầu'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.capturedCount,
    required this.totalCount,
    required this.activePose,
    required this.progress,
  });

  final int capturedCount;
  final int totalCount;
  final String activePose;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParentIconWell(icon: Icons.face_retouching_natural_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã chụp $capturedCount/$totalCount góc mặt',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đang căn góc: $activePose',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: AppTheme.primarySoft,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturePreviewGrid extends StatelessWidget {
  const _CapturePreviewGrid({required this.captures});

  final Map<MobileFacePose, XFile> captures;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: MobileFacePose.values.map((pose) {
        final file = captures[pose];
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: file == null ? AppTheme.primarySoft : AppTheme.surface,
              border: Border.all(
                color: file == null
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : AppTheme.accentGreen.withValues(alpha: 0.5),
                width: file == null ? 1 : 1.5,
              ),
            ),
            child: file == null
                ? Center(
                    child: Text(
                      _poseShortLabel(pose),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
        );
      }).toList(),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.result,
    required this.studentName,
    required this.onDone,
    required this.onReset,
  });

  final FaceEnrollmentResult result;
  final String studentName;
  final VoidCallback onDone;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ParentBanner(
          icon: Icons.check_circle_outline,
          tone: ParentBannerTone.success,
          text:
              'Đã lưu 5 góc mặt cho $studentName. Trạng thái: ${result.profileStatus ?? 'ACTIVE'}.',
        ),
        const SizedBox(height: 12),
        _ResultDetails(
          rows: {
            'studentId': result.studentId,
            'schoolId': result.schoolId,
            'embedding': result.embeddingId ?? '-',
            'dimension': result.embeddingDimension.toString(),
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onDone,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Hoàn tất'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Chụp lại'),
        ),
      ],
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Column(
        children: rows.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _poseRequestKey(MobileFacePose pose) {
  return switch (pose) {
    MobileFacePose.center => 'center',
    MobileFacePose.right => 'right',
    MobileFacePose.left => 'left',
    MobileFacePose.up => 'up',
    MobileFacePose.down => 'down',
  };
}

String _poseLabel(MobileFacePose pose) {
  return switch (pose) {
    MobileFacePose.center => 'chính giữa',
    MobileFacePose.right => 'bên phải',
    MobileFacePose.left => 'bên trái',
    MobileFacePose.up => 'nhìn lên',
    MobileFacePose.down => 'nhìn xuống',
  };
}

String _poseShortLabel(MobileFacePose pose) {
  return switch (pose) {
    MobileFacePose.center => 'Giữa',
    MobileFacePose.right => 'Phải',
    MobileFacePose.left => 'Trái',
    MobileFacePose.up => 'Lên',
    MobileFacePose.down => 'Xuống',
  };
}

String _poseHint(MobileFacePose pose) {
  return switch (pose) {
    MobileFacePose.center => 'Nhìn thẳng vào camera, giữ mặt trong khung.',
    MobileFacePose.right => 'Quay mặt nhẹ sang phải cho đến khi máy tự chụp.',
    MobileFacePose.left => 'Quay mặt nhẹ sang trái cho đến khi máy tự chụp.',
    MobileFacePose.up =>
      'Ngẩng mặt nhẹ lên, có thể lệch khỏi giữa khung. Giữ 1–2 giây để máy tự chụp.',
    MobileFacePose.down => 'Cúi mặt nhẹ xuống cho đến khi máy tự chụp.',
  };
}

String _friendlyError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '');
  if (text.contains('Chưa xác định được tour') ||
      text.contains('Chua xac dinh duoc tour')) {
    return 'Chưa xác định được tour của học sinh. Vui lòng liên kết lại chuyến đi trước khi đăng ký khuôn mặt.';
  }
  if (text.contains('FACE-AUTHZ-DECLINED')) {
    return 'Phụ huynh đã từ chối đồng thuận khuôn mặt. Không thể lấy dữ liệu khuôn mặt hộ học sinh này.';
  }
  if (text.contains('FACE-TEACHER-VEHICLE-001')) {
    return 'Chỉ được đăng ký khuôn mặt cho học sinh trên xe được phân công.';
  }
  if (text.contains('FACE-TEACHER-SCOPE-001')) {
    return 'Bạn chưa được phân quyền đăng ký khuôn mặt trên tour này.';
  }
  if (text.contains('FACE-AUTHZ-001') || text.contains('FACE_ATTENDANCE')) {
    return 'Học sinh chưa được đồng thuận điểm danh khuôn mặt cho tour này. Cần phụ huynh đồng ý qua link trước khi lưu 5 góc mặt.';
  }
  if (text.contains('SocketException') ||
      text.contains('connection') ||
      text.contains('timed out')) {
    return 'Lỗi kết nối mạng. Kiểm tra lại mạng rồi thử lại.';
  }
  return text;
}
