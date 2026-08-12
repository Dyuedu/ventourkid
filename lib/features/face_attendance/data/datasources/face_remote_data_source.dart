import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/mobile_face_embedding.dart';

abstract interface class FaceRemoteDataSource {
  Future<FaceEnrollmentResult> enroll({
    required String studentId,
    required String schoolId,
    required MobileFaceEmbedding face,
    String? consentRecordId,
  });

  Future<FaceEnrollmentResult> enrollMultiAngle({
    required String studentId,
    required Map<String, String> imagePathsByPose,
    String? schoolId,
  });

  Future<List<FaceNeedsEnrollStudent>> listStudentsNeedingEnroll(String tourId);

  Future<void> authorizeFaceAttendance({
    required String studentId,
    required String operationPlanId,
    bool authorized,
  });

  Future<FaceAttendanceCaptureResult> captureAttendance({
    required String tourId,
    required MobileFaceEmbedding face,
    String? schoolId,
    String? groupId,
    String? checkpointId,
    String? attendanceSessionId,
    int topK,
    double matchThreshold,
  });

  Future<FaceAttendanceCaptureResult> captureAttendanceImage({
    required String tourId,
    required String imagePath,
    String? schoolId,
    String? groupId,
    String? checkpointId,
    String? attendanceSessionId,
    int topK,
    double matchThreshold,
  });
}

class FaceRemoteDataSourceImpl implements FaceRemoteDataSource {
  FaceRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<FaceEnrollmentResult> enroll({
    required String studentId,
    required String schoolId,
    required MobileFaceEmbedding face,
    String? consentRecordId,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/face/enrollments',
      data: {
        'studentId': studentId,
        if (schoolId.isNotEmpty) 'schoolId': schoolId,
        if (consentRecordId != null && consentRecordId.isNotEmpty)
          'consentRecordId': consentRecordId,
        'imageUrl': face.imageUrl,
        'storageProvider': 'MOBILE_ON_DEVICE',
        'pose': 'FRONTAL',
        'qualityScore': face.qualityScore,
        'accepted': true,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'modelName': face.modelName,
        'modelVersion': face.modelVersion,
        'embedding': face.embedding,
        'primaryEmbedding': true,
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid face enrollment response');
    }
    return FaceEnrollmentResult.fromJson(data);
  }

  @override
  Future<FaceEnrollmentResult> enrollMultiAngle({
    required String studentId,
    required Map<String, String> imagePathsByPose,
    String? schoolId,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('studentId', studentId));
    if (schoolId != null && schoolId.isNotEmpty) {
      form.fields.add(MapEntry('schoolId', schoolId));
    }
    for (final entry in imagePathsByPose.entries) {
      form.files.add(
        MapEntry(
          entry.key,
          await MultipartFile.fromFile(
            entry.value,
            filename: '${entry.key}.jpg',
            contentType: MultipartFile.lookupMediaType(entry.value),
          ),
        ),
      );
    }

    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/face/enrollments/multi-angle',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid multi-angle face enrollment response',
      );
    }
    return FaceEnrollmentResult.fromJson(data);
  }

  @override
  Future<List<FaceNeedsEnrollStudent>> listStudentsNeedingEnroll(String tourId) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/face/tours/$tourId/students/needs-enroll',
    );
    final data = response.data?['data'];
    if (data is! List) {
      throw const FormatException('Invalid needs-enroll response');
    }
    return data
        .whereType<Map>()
        .map((item) => FaceNeedsEnrollStudent.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> authorizeFaceAttendance({
    required String studentId,
    required String operationPlanId,
    bool authorized = true,
  }) async {
    await _dio.dio.post<Map<String, dynamic>>(
      '/v1/parents/children/$studentId/face/authorization',
      data: {
        'operationPlanId': operationPlanId,
        'authorized': authorized,
        'confirmationNote': 'Parent confirmed in mobile face enrollment',
      },
    );
  }

  @override
  Future<FaceAttendanceCaptureResult> captureAttendance({
    required String tourId,
    required MobileFaceEmbedding face,
    String? schoolId,
    String? groupId,
    String? checkpointId,
    String? attendanceSessionId,
    int topK = 3,
    double matchThreshold = 0.72,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/face/attendance/captures',
      data: {
        'tourId': tourId,
        if (schoolId != null && schoolId.isNotEmpty) 'schoolId': schoolId,
        if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
        if (attendanceSessionId != null && attendanceSessionId.isNotEmpty)
          'attendanceSessionId': attendanceSessionId,
        'inputImageUrl': face.imageUrl,
        'modelName': face.modelName,
        'modelVersion': face.modelVersion,
        'embedding': face.embedding,
        'topK': topK,
        'matchThreshold': matchThreshold,
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid face attendance response');
    }
    return FaceAttendanceCaptureResult.fromJson(data);
  }

  @override
  Future<FaceAttendanceCaptureResult> captureAttendanceImage({
    required String tourId,
    required String imagePath,
    String? schoolId,
    String? groupId,
    String? checkpointId,
    String? attendanceSessionId,
    int topK = 3,
    double matchThreshold = 0.72,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imagePath,
        filename: 'attendance-scan.jpg',
        contentType: MultipartFile.lookupMediaType(imagePath),
      ),
    });
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/face/attendance/captures/image',
      data: form,
      queryParameters: {
        'tourId': tourId,
        if (schoolId != null && schoolId.isNotEmpty) 'schoolId': schoolId,
        if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
        if (attendanceSessionId != null && attendanceSessionId.isNotEmpty)
          'attendanceSessionId': attendanceSessionId,
        'topK': topK,
        'matchThreshold': matchThreshold,
      },
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid face attendance image response');
    }
    return FaceAttendanceCaptureResult.fromJson(data);
  }
}

class FaceNeedsEnrollStudent {
  const FaceNeedsEnrollStudent({
    required this.rosterStudentId,
    required this.fullName,
    this.className,
    this.operationVehicleId,
    this.vehicleLabel,
  });

  final String rosterStudentId;
  final String fullName;
  final String? className;
  final String? operationVehicleId;
  final String? vehicleLabel;

  factory FaceNeedsEnrollStudent.fromJson(Map<String, dynamic> json) {
    return FaceNeedsEnrollStudent(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Học sinh',
      className: json['className']?.toString(),
      operationVehicleId: json['operationVehicleId']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
    );
  }
}
