import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../../domain/entities/mobile_face_embedding.dart';

enum MobileFacePose { center, right, left, up, down }

class MobileFaceDetectionResult {
  const MobileFaceDetectionResult({
    required this.ready,
    required this.message,
    required this.faceCount,
    required this.qualityScore,
    this.pose,
  });

  final bool ready;
  final String message;
  final int faceCount;
  final double qualityScore;
  final MobileFacePose? pose;
}

class MobileFaceEmbeddingException implements Exception {
  const MobileFaceEmbeddingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileFaceEmbeddingService {
  MobileFaceEmbeddingService({
    FaceDetector? faceDetector,
    FaceDetector? streamFaceDetector,
    String modelAssetPath = defaultModelAssetPath,
  }) : _faceDetector =
           faceDetector ??
           FaceDetector(
             options: FaceDetectorOptions(
               performanceMode: FaceDetectorMode.accurate,
               enableLandmarks: true,
               enableContours: false,
               enableClassification: false,
             ),
           ),
       _streamFaceDetector =
           streamFaceDetector ??
           FaceDetector(
             options: FaceDetectorOptions(
               performanceMode: FaceDetectorMode.fast,
               enableLandmarks: false,
               enableContours: false,
               enableClassification: false,
             ),
           ),
       _modelAssetPath = modelAssetPath;

  static const defaultModelAssetPath = 'assets/models/insightface_mobile.onnx';
  static const modelName = 'InsightFace';
  static const modelVersion = 'buffalo_l-mobile-onnx-v1';
  static const _inputWidth = 112;
  static const _inputHeight = 112;
  static const _inputChannels = 3;
  static const _expectedEmbeddingDimension = 512;
  static const _arcFaceDestination = <math.Point<double>>[
    math.Point(38.2946, 51.6963),
    math.Point(73.5318, 51.5014),
    math.Point(56.0252, 71.7366),
    math.Point(41.5493, 92.3655),
    math.Point(70.7299, 92.2041),
  ];

  final FaceDetector _faceDetector;
  final FaceDetector _streamFaceDetector;
  final String _modelAssetPath;
  OrtSession? _session;
  bool _ortInitialized = false;

  Future<MobileFaceDetectionResult> assessImage(
    String imagePath, {
    MobileFacePose pose = MobileFacePose.center,
    bool relaxed = false,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return const MobileFaceDetectionResult(
        ready: false,
        message: 'Không tìm thấy ảnh camera.',
        faceCount: 0,
        qualityScore: 0,
      );
    }

    final faces = await _faceDetector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final bytes = await file.readAsBytes();
    final decodedRaw = img.decodeImage(bytes);
    final decoded = decodedRaw == null ? null : img.bakeOrientation(decodedRaw);
    if (decoded == null) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Không đọc được ảnh camera.',
        faceCount: faces.length,
        qualityScore: 0,
        pose: pose,
      );
    }

    return _assessFaces(
      faces,
      imageWidth: decoded.width.toDouble(),
      imageHeight: decoded.height.toDouble(),
      pose: pose,
      relaxed: relaxed,
    );
  }

  Future<MobileFaceDetectionResult?> assessCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    MobileFacePose pose = MobileFacePose.center,
    bool relaxed = false,
  }) async {
    final inputImage = _inputImageFromCameraImage(
      image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) return null;

    final faces = await _streamFaceDetector.processImage(inputImage);
    return _assessFaces(
      faces,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      pose: pose,
      relaxed: relaxed,
    );
  }

  Future<String> normalizeJpegForUpload(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const MobileFaceEmbeddingException('Không tìm thấy ảnh camera.');
    }

    final bytes = await file.readAsBytes();
    final decodedRaw = img.decodeImage(bytes);
    if (decodedRaw == null) {
      throw const MobileFaceEmbeddingException('Không đọc được ảnh camera.');
    }

    final decoded = img.bakeOrientation(decodedRaw);
    final normalized = _resizeForUpload(decoded);
    final normalizedPath =
        '${file.parent.path}${Platform.pathSeparator}face-upload-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(
      normalizedPath,
    ).writeAsBytes(img.encodeJpg(normalized, quality: 94), flush: true);
    return normalizedPath;
  }

  Future<MobileFaceEmbedding> createEmbedding(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const MobileFaceEmbeddingException('Không tìm thấy ảnh đã chọn.');
    }

    final faces = await _faceDetector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    if (faces.isEmpty) {
      throw const MobileFaceEmbeddingException(
        'Không phát hiện khuôn mặt. Vui lòng chụp rõ mặt học sinh.',
      );
    }
    if (faces.length > 1) {
      throw const MobileFaceEmbeddingException(
        'Ảnh có nhiều khuôn mặt. Vui lòng chụp từng học sinh một.',
      );
    }

    final bytes = await file.readAsBytes();
    final decodedRaw = img.decodeImage(bytes);
    final decoded = decodedRaw == null ? null : img.bakeOrientation(decodedRaw);
    if (decoded == null) {
      throw const MobileFaceEmbeddingException('Không đọc được ảnh khuôn mặt.');
    }

    final session = await _loadSession();
    final aligned = _alignFace(decoded, faces.first);
    final embedding = await _runOnnx(session, aligned);

    return MobileFaceEmbedding(
      embedding: _l2Normalize(embedding),
      faceCount: faces.length,
      modelName: modelName,
      modelVersion: modelVersion,
      qualityScore: _qualityScore(decoded, faces.first),
      imageUrl: 'mobile://face/${_fileName(imagePath)}',
    );
  }

  Future<OrtSession> _loadSession() async {
    final current = _session;
    if (current != null) {
      return current;
    }
    try {
      if (!_ortInitialized) {
        OrtEnv.instance.init();
        _ortInitialized = true;
      }
      final sessionOptions = OrtSessionOptions()
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      final rawAssetFile = await rootBundle.load(_modelAssetPath);
      final modelBytes = rawAssetFile.buffer.asUint8List();
      final session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      _session = session;
      sessionOptions.release();
      return session;
    } on Object catch (error) {
      throw MobileFaceEmbeddingException(
        'Chưa cấu hình model ONNX hợp lệ. '
        'Hãy thay $_modelAssetPath bằng model InsightFace-compatible ONNX. '
        'Chi tiết: $error',
      );
    }
  }

  Future<List<double>> _runOnnx(OrtSession session, img.Image image) async {
    final inputName = session.inputNames.isEmpty
        ? 'input'
        : session.inputNames.first;
    final input = OrtValueTensor.createTensorWithDataList(
      _imageToNchwFloatInput(image),
      [1, _inputChannels, _inputHeight, _inputWidth],
    );
    final runOptions = OrtRunOptions();
    final outputs = <OrtValue?>[];
    try {
      outputs.addAll(session.run(runOptions, {inputName: input}));
      if (outputs.isEmpty || outputs.first == null) {
        throw const MobileFaceEmbeddingException(
          'Model ONNX không trả embedding.',
        );
      }
      final embedding = _flattenNumbers(outputs.first!.value);
      if (embedding.isEmpty) {
        throw const MobileFaceEmbeddingException(
          'Model ONNX trả embedding rỗng.',
        );
      }
      if (embedding.length != _expectedEmbeddingDimension) {
        throw MobileFaceEmbeddingException(
          'Model ONNX must return $_expectedEmbeddingDimension dimensions, '
          'but returned ${embedding.length}.',
        );
      }
      return embedding;
    } finally {
      input.release();
      runOptions.release();
      for (final output in outputs) {
        output?.release();
      }
    }
  }

  img.Image _alignFace(img.Image source, Face face) {
    final landmarks = _arcFaceSourceLandmarks(face);
    final transform = _estimateSimilarityTransform(
      landmarks,
      _arcFaceDestination,
    );
    return _warpAffine(source, transform, _inputWidth, _inputHeight);
  }

  List<math.Point<double>> _arcFaceSourceLandmarks(Face face) {
    final eyeA = _requiredLandmark(face, FaceLandmarkType.leftEye);
    final eyeB = _requiredLandmark(face, FaceLandmarkType.rightEye);
    final mouthA = _requiredLandmark(face, FaceLandmarkType.leftMouth);
    final mouthB = _requiredLandmark(face, FaceLandmarkType.rightMouth);
    final eyes = [eyeA, eyeB]..sort((a, b) => a.x.compareTo(b.x));
    final mouth = [mouthA, mouthB]..sort((a, b) => a.x.compareTo(b.x));

    return [
      eyes[0],
      eyes[1],
      _requiredLandmark(face, FaceLandmarkType.noseBase),
      mouth[0],
      mouth[1],
    ];
  }

  math.Point<double> _requiredLandmark(Face face, FaceLandmarkType type) {
    final position = face.landmarks[type]?.position;
    if (position == null) {
      throw const MobileFaceEmbeddingException(
        'Face landmarks are incomplete; capture a clearer frontal face.',
      );
    }
    return math.Point(position.x.toDouble(), position.y.toDouble());
  }

  _SimilarityTransform _estimateSimilarityTransform(
    List<math.Point<double>> source,
    List<math.Point<double>> destination,
  ) {
    var sourceMeanX = 0.0;
    var sourceMeanY = 0.0;
    var destinationMeanX = 0.0;
    var destinationMeanY = 0.0;
    for (var i = 0; i < source.length; i++) {
      sourceMeanX += source[i].x;
      sourceMeanY += source[i].y;
      destinationMeanX += destination[i].x;
      destinationMeanY += destination[i].y;
    }
    sourceMeanX /= source.length;
    sourceMeanY /= source.length;
    destinationMeanX /= destination.length;
    destinationMeanY /= destination.length;

    var a = 0.0;
    var b = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < source.length; i++) {
      final sx = source[i].x - sourceMeanX;
      final sy = source[i].y - sourceMeanY;
      final dx = destination[i].x - destinationMeanX;
      final dy = destination[i].y - destinationMeanY;
      a += dx * sx + dy * sy;
      b += dy * sx - dx * sy;
      denominator += sx * sx + sy * sy;
    }
    if (denominator == 0) {
      throw const MobileFaceEmbeddingException(
        'Unable to align face from detected landmarks.',
      );
    }

    a /= denominator;
    b /= denominator;
    final tx = destinationMeanX - a * sourceMeanX + b * sourceMeanY;
    final ty = destinationMeanY - b * sourceMeanX - a * sourceMeanY;
    return _SimilarityTransform(a, b, tx, ty);
  }

  img.Image _warpAffine(
    img.Image source,
    _SimilarityTransform transform,
    int width,
    int height,
  ) {
    final output = img.Image(width: width, height: height, numChannels: 3);
    final determinant = transform.a * transform.a + transform.b * transform.b;
    if (determinant == 0) {
      throw const MobileFaceEmbeddingException(
        'Unable to align face with an empty transform.',
      );
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final translatedX = x - transform.tx;
        final translatedY = y - transform.ty;
        final sourceX =
            (transform.a * translatedX + transform.b * translatedY) /
            determinant;
        final sourceY =
            (-transform.b * translatedX + transform.a * translatedY) /
            determinant;
        final rgb = _sampleRgb(source, sourceX, sourceY);
        output.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }
    return output;
  }

  List<int> _sampleRgb(img.Image source, double x, double y) {
    final clampedX = _clampDouble(x, 0, source.width - 1);
    final clampedY = _clampDouble(y, 0, source.height - 1);
    final x0 = clampedX.floor();
    final y0 = clampedY.floor();
    final x1 = _clamp(x0 + 1, 0, source.width - 1);
    final y1 = _clamp(y0 + 1, 0, source.height - 1);
    final wx = clampedX - x0;
    final wy = clampedY - y0;
    final p00 = source.getPixel(x0, y0);
    final p10 = source.getPixel(x1, y0);
    final p01 = source.getPixel(x0, y1);
    final p11 = source.getPixel(x1, y1);

    int channel(num Function(img.Pixel pixel) pick) {
      final top = pick(p00) * (1 - wx) + pick(p10) * wx;
      final bottom = pick(p01) * (1 - wx) + pick(p11) * wx;
      return (top * (1 - wy) + bottom * wy).round().clamp(0, 255).toInt();
    }

    return [
      channel((pixel) => pixel.r),
      channel((pixel) => pixel.g),
      channel((pixel) => pixel.b),
    ];
  }

  Float32List _imageToNchwFloatInput(img.Image image) {
    final planeSize = image.width * image.height;
    final values = Float32List(_inputChannels * planeSize);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final offset = y * image.width + x;
        values[offset] = (pixel.r.toDouble() - 127.5) / 127.5;
        values[planeSize + offset] = (pixel.g.toDouble() - 127.5) / 127.5;
        values[planeSize * 2 + offset] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }
    return values;
  }

  List<double> _flattenNumbers(Object? value) {
    final result = <double>[];

    void collect(Object? item) {
      if (item is num) {
        result.add(item.toDouble());
        return;
      }
      if (item is Iterable) {
        for (final child in item) {
          collect(child);
        }
      }
    }

    collect(value);
    return result;
  }

  List<double> _l2Normalize(List<double> values) {
    final norm = math.sqrt(values.fold<double>(0, (sum, x) => sum + x * x));
    if (norm == 0) {
      return values;
    }
    return values.map((value) => value / norm).toList(growable: false);
  }

  double _qualityScore(img.Image image, Face face) {
    final box = face.boundingBox;
    final faceArea = box.width * box.height;
    final imageArea = image.width * image.height;
    if (imageArea == 0) {
      return 0;
    }
    return (faceArea / imageArea).clamp(0.0, 1.0).toDouble();
  }

  MobileFaceDetectionResult _assessFaces(
    List<Face> faces, {
    required double imageWidth,
    required double imageHeight,
    required MobileFacePose pose,
    bool relaxed = false,
  }) {
    if (faces.isEmpty) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Đưa mặt vào khung hình.',
        faceCount: 0,
        qualityScore: 0,
        pose: pose,
      );
    }
    if (faces.length > 1) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Chỉ giữ một khuôn mặt trong khung.',
        faceCount: faces.length,
        qualityScore: 0,
        pose: pose,
      );
    }

    final face = faces.first;
    final box = face.boundingBox;
    final widthRatio = box.width / imageWidth;
    final heightRatio = box.height / imageHeight;
    final centerOffsetX =
        ((box.left + box.width / 2) - imageWidth / 2).abs() / imageWidth;
    final centerOffsetY =
        ((box.top + box.height / 2) - imageHeight / 2).abs() / imageHeight;
    final quality = (box.width * box.height / (imageWidth * imageHeight))
        .clamp(0.0, 1.0)
        .toDouble();

    final minWidth = relaxed ? 0.16 : 0.27;
    final minHeight = switch (pose) {
      MobileFacePose.up || MobileFacePose.down when relaxed => 0.15,
      _ => relaxed ? 0.18 : 0.31,
    };
    final maxWidth = relaxed ? 0.84 : 0.72;
    final maxHeight = relaxed ? 0.90 : 0.84;
    final maxOffsetX = relaxed ? 0.22 : 0.12;
    final maxOffsetY = relaxed ? 0.22 : 0.14;
    final maxRoll = relaxed ? 16 : 8;
    final faceCenterY = box.top + box.height / 2;
    final normalizedCenterY = (faceCenterY - imageHeight / 2) / imageHeight;

    if (widthRatio < minWidth || heightRatio < minHeight) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Tiến mặt gần camera hơn.',
        faceCount: faces.length,
        qualityScore: quality,
        pose: pose,
      );
    }
    if (widthRatio > maxWidth || heightRatio > maxHeight) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Lùi mặt xa camera một chút.',
        faceCount: faces.length,
        qualityScore: quality,
        pose: pose,
      );
    }
    final offCenter =
        centerOffsetX > maxOffsetX ||
        switch (pose) {
          MobileFacePose.up when relaxed =>
            normalizedCenterY > 0.10 || normalizedCenterY < -0.38,
          MobileFacePose.up =>
            normalizedCenterY > 0.08 || normalizedCenterY < -0.30,
          MobileFacePose.down when relaxed =>
            normalizedCenterY < -0.10 || normalizedCenterY > 0.38,
          MobileFacePose.down =>
            normalizedCenterY < -0.08 || normalizedCenterY > 0.30,
          _ => centerOffsetY > maxOffsetY,
        };
    if (offCenter) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Căn mặt vào giữa khung.',
        faceCount: faces.length,
        qualityScore: quality,
        pose: pose,
      );
    }

    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (roll.abs() > maxRoll) {
      return MobileFaceDetectionResult(
        ready: false,
        message: 'Giữ đầu thẳng, không nghiêng.',
        faceCount: faces.length,
        qualityScore: quality,
        pose: pose,
      );
    }

    final poseMessage = switch (pose) {
      MobileFacePose.center
          when yaw.abs() > (relaxed ? 12 : 6) ||
              pitch.abs() > (relaxed ? 12 : 7) =>
        'Nhìn thẳng vào camera.',
      MobileFacePose.right when yaw > (relaxed ? -6 : -12) =>
        'Quay mặt nhẹ sang phải.',
      MobileFacePose.left when yaw < (relaxed ? 6 : 12) =>
        'Quay mặt nhẹ sang trái.',
      MobileFacePose.up when pitch < (relaxed ? 7 : 12) => 'Ngẩng mặt nhẹ lên.',
      MobileFacePose.down when pitch > (relaxed ? -7 : -12) =>
        'Cúi mặt nhẹ xuống.',
      _ => null,
    };
    if (poseMessage != null) {
      return MobileFaceDetectionResult(
        ready: false,
        message: poseMessage,
        faceCount: faces.length,
        qualityScore: quality,
        pose: pose,
      );
    }

    return MobileFaceDetectionResult(
      ready: true,
      message: 'Khuôn mặt đã ổn định.',
      faceCount: faces.length,
      qualityScore: quality,
      pose: pose,
    );
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _inputImageRotation(camera, deviceOrientation);
    if (rotation == null) return null;

    final formatRaw = image.format.raw;
    final rawValue = formatRaw is int ? formatRaw : int.tryParse('$formatRaw');
    if (rawValue == null) return null;
    final format = InputImageFormatValue.fromRawValue(rawValue);
    if (format == null) return null;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (format != InputImageFormat.nv21 || image.planes.length != 1) {
        return null;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
        return null;
      }
    } else {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation = orientations[deviceOrientation];
    if (deviceRotation == null) return null;

    final rotation = defaultTargetPlatform == TargetPlatform.iOS
        ? camera.sensorOrientation
        : camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation);
  }

  int _clamp(int value, int min, int max) {
    return math.max(min, math.min(max, value));
  }

  double _clampDouble(double value, num min, num max) {
    return math.max(min.toDouble(), math.min(max.toDouble(), value));
  }

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? 'capture.jpg' : parts.last;
  }

  img.Image _resizeForUpload(img.Image source, {int minSide = 720}) {
    final shortSide = math.min(source.width, source.height);
    if (shortSide >= minSide) return source;
    final scale = minSide / shortSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  void dispose() {
    _faceDetector.close();
    _streamFaceDetector.close();
    _session?.release();
    if (_ortInitialized) {
      OrtEnv.instance.release();
      _ortInitialized = false;
    }
  }
}

class _SimilarityTransform {
  const _SimilarityTransform(this.a, this.b, this.tx, this.ty);

  final double a;
  final double b;
  final double tx;
  final double ty;
}
