import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../data/services/mobile_face_embedding_service.dart';

class LiveFaceCapturePanel extends StatefulWidget {
  const LiveFaceCapturePanel({
    super.key,
    required this.faceService,
    required this.pose,
    required this.onCaptured,
    this.enabled = true,
    this.title,
    this.subtitle,
    this.requiredStableFrames = 2,
    this.scanInterval = const Duration(milliseconds: 1100),
    this.normalizeCapture = true,
    this.relaxedDetection = false,
  });

  final MobileFaceEmbeddingService faceService;
  final MobileFacePose pose;
  final FutureOr<void> Function(XFile file, MobileFaceDetectionResult detection)
  onCaptured;
  final bool enabled;
  final String? title;
  final String? subtitle;
  final int requiredStableFrames;
  final Duration scanInterval;
  final bool normalizeCapture;
  final bool relaxedDetection;

  @override
  State<LiveFaceCapturePanel> createState() => _LiveFaceCapturePanelState();
}

class _LiveFaceCapturePanelState extends State<LiveFaceCapturePanel> {
  CameraController? _controller;
  Timer? _timer;
  List<CameraDescription> _cameras = const [];
  int? _selectedCameraIndex;
  bool _initializing = true;
  bool _analyzingFrame = false;
  bool _capturing = false;
  bool _completed = false;
  bool _switchingCamera = false;
  int _cameraStartToken = 0;
  int _stableFrames = 0;
  DateTime _lastFrameScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _status = 'Đang mở camera...';

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void didUpdateWidget(covariant LiveFaceCapturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose || oldWidget.enabled != widget.enabled) {
      _completed = false;
      _stableFrames = 0;
      _status = widget.enabled ? 'Đưa mặt vào khung hình.' : 'Đang tạm dừng.';
      if (widget.enabled) {
        _startScanLoop();
      } else {
        unawaited(_stopScanLoop());
      }
    }
  }

  Future<void> _startCamera() async {
    final startToken = ++_cameraStartToken;
    await _stopScanLoop();
    setState(() {
      _initializing = true;
      _status = 'Đang mở camera...';
    });

    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      await oldController.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NO_CAMERA', 'Không tìm thấy camera trên máy.');
      }
      _cameras = cameras;
      final cameraIndex = _resolveCameraIndex(cameras);
      _selectedCameraIndex = cameraIndex;
      final selectedCamera = cameras[cameraIndex];
      CameraController? controller;
      Object? lastError;
      for (final preset in const [
        ResolutionPreset.low,
        ResolutionPreset.medium,
      ]) {
        controller = CameraController(
          selectedCamera,
          preset,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        try {
          await controller.initialize();
          lastError = null;
          break;
        } on Object catch (error) {
          lastError = error;
          await controller.dispose();
          controller = null;
          if (!_looksLikeSurfaceCombinationError(error)) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (controller == null) {
        throw lastError ??
            CameraException('CAMERA_INIT_FAILED', 'Không mở được camera.');
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (startToken != _cameraStartToken) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _status = 'Đưa mặt vào khung hình.';
      });
      _startScanLoop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _status = _cameraErrorMessage(error);
      });
    }
  }

  void _startScanLoop() {
    _timer?.cancel();
    final controller = _controller;
    if (!widget.enabled ||
        _completed ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }
    if (Platform.isAndroid) {
      _startFallbackCaptureLoop();
      return;
    }
    _lastFrameScanAt = DateTime.fromMillisecondsSinceEpoch(0);
    unawaited(
      controller.startImageStream(_onCameraImage).catchError((Object error) {
        if (!mounted || _completed) return;
        _startFallbackCaptureLoop();
      }),
    );
  }

  void _startFallbackCaptureLoop() {
    _timer?.cancel();
    if (!widget.enabled || _completed) return;
    _timer = Timer.periodic(
      const Duration(milliseconds: 2200),
      (_) => _scanFileOnce(),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 650)).then((_) {
        if (mounted && widget.enabled && !_completed) {
          return _scanFileOnce();
        }
      }),
    );
  }

  int _resolveCameraIndex(List<CameraDescription> cameras) {
    final selected = _selectedCameraIndex;
    if (selected != null && selected >= 0 && selected < cameras.length) {
      return selected;
    }
    final frontIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    return frontIndex >= 0 ? frontIndex : 0;
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera || _cameras.length < 2) return;
    setState(() {
      _switchingCamera = true;
      _completed = false;
      _stableFrames = 0;
      _selectedCameraIndex =
          ((_selectedCameraIndex ?? _resolveCameraIndex(_cameras)) + 1) %
          _cameras.length;
    });
    try {
      await _startCamera();
    } finally {
      if (mounted) {
        setState(() => _switchingCamera = false);
      }
    }
  }

  void _onCameraImage(CameraImage image) {
    final controller = _controller;
    if (!mounted ||
        !widget.enabled ||
        _completed ||
        _capturing ||
        _analyzingFrame ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameScanAt) < widget.scanInterval) {
      return;
    }
    _lastFrameScanAt = now;
    _analyzingFrame = true;
    unawaited(
      _assessCameraFrame(image).whenComplete(() => _analyzingFrame = false),
    );
  }

  Future<void> _assessCameraFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final detection = await widget.faceService.assessCameraImage(
        image,
        camera: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
        pose: widget.pose,
        relaxed: widget.relaxedDetection,
      );
      if (!mounted || detection == null) return;

      _setStatus(detection.message);
      if (!detection.ready) {
        _stableFrames = 0;
        return;
      }

      _stableFrames += 1;
      if (_stableFrames >= widget.requiredStableFrames) {
        await _captureConfirmedFace(detection);
      }
    } on Object catch (error) {
      if (!mounted) return;
      _stableFrames = 0;
      _setStatus('Đang thử lại: ${_cameraErrorMessage(error)}');
    }
  }

  Future<void> _scanFileOnce() async {
    final controller = _controller;
    if (!mounted ||
        !widget.enabled ||
        _completed ||
        _capturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    _capturing = true;
    XFile? file;
    try {
      file = await controller.takePicture();
      final detection = await widget.faceService.assessImage(
        file.path,
        pose: widget.pose,
        relaxed: widget.relaxedDetection,
      );
      if (!mounted) return;

      setState(() => _status = detection.message);
      if (detection.ready) {
        _stableFrames += 1;
        if (_stableFrames >= widget.requiredStableFrames) {
          await _finishWithCapturedFile(file, detection);
          return;
        }
      } else {
        _stableFrames = 0;
      }
      await _deleteQuietly(file.path);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Đang thử lại: ${_cameraErrorMessage(error)}');
      if (file != null) {
        await _deleteQuietly(file.path);
      }
    } finally {
      _capturing = false;
    }
  }

  Future<void> _captureConfirmedFace(
    MobileFaceDetectionResult detection,
  ) async {
    final controller = _controller;
    if (_capturing ||
        _completed ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _capturing = true;
    _completed = true;
    XFile? file;
    try {
      await _stopScanLoop();
      if (!mounted) return;
      _setStatus('Đã phát hiện khuôn mặt ổn định.');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      file = await controller.takePicture();
      await _finishWithCapturedFile(file, detection);
    } on Object catch (error) {
      _completed = false;
      _stableFrames = 0;
      if (!mounted) return;
      _setStatus('Đang thử lại: ${_cameraErrorMessage(error)}');
      if (file != null) {
        await _deleteQuietly(file.path);
      }
      _startScanLoop();
    } finally {
      _capturing = false;
    }
  }

  Future<void> _finishWithCapturedFile(
    XFile file,
    MobileFaceDetectionResult detection,
  ) async {
    _completed = true;
    await _stopScanLoop();
    if (mounted) {
      _setStatus('Đã phát hiện khuôn mặt ổn định.');
    }
    XFile capturedFile = file;
    if (widget.normalizeCapture) {
      final normalizedPath = await widget.faceService.normalizeJpegForUpload(
        file.path,
      );
      capturedFile = normalizedPath == file.path ? file : XFile(normalizedPath);
      if (normalizedPath != file.path) {
        await _deleteQuietly(file.path);
      }
    }
    await widget.onCaptured(capturedFile, detection);
  }

  Future<void> _stopScanLoop() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  void _setStatus(String message) {
    if (!mounted || _status == message) return;
    setState(() => _status = message);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup for discarded probe frames.
    }
  }

  @override
  void dispose() {
    _cameraStartToken += 1;
    _timer?.cancel();
    final controller = _controller;
    if (controller?.value.isStreamingImages == true) {
      unawaited(controller!.stopImageStream().catchError((_) {}));
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_initializing ||
                        controller == null ||
                        !controller.value.isInitialized)
                      const ColoredBox(
                        color: AppTheme.surfaceContainer,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      CameraPreview(controller),
                    if (_cameras.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton.filledTonal(
                          tooltip: 'Đổi camera',
                          onPressed:
                              _initializing || _capturing || _switchingCamera
                              ? null
                              : _switchCamera,
                          icon: _switchingCamera
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.flip_camera_ios_rounded),
                        ),
                      ),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.72,
                        heightFactor: 0.58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.86),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.black.withValues(alpha: 0.52),
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _looksLikeSurfaceCombinationError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('surface combination') ||
      text.contains('usecase') ||
      text.contains('camera2') ||
      text.contains('camerax');
}

String _cameraErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('no supported surface combination') ||
      text.contains('surface combination')) {
    return 'Camera của thiết bị không hỗ trợ cấu hình xem trước hiện tại. Ứng dụng đã thử hạ chất lượng camera, vui lòng đóng màn hình rồi mở lại.';
  }
  if (text.contains('cameraaccessdenied') || text.contains('permission')) {
    return 'Ứng dụng chưa có quyền camera. Vui lòng cấp quyền camera rồi thử lại.';
  }
  if (text.contains('no_camera')) {
    return 'Không tìm thấy camera trên thiết bị.';
  }
  return 'Không mở được camera. Vui lòng đóng màn hình rồi thử lại.';
}
