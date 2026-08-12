class MobileFaceEmbedding {
  const MobileFaceEmbedding({
    required this.embedding,
    required this.faceCount,
    required this.modelName,
    required this.modelVersion,
    required this.qualityScore,
    required this.imageUrl,
  });

  final List<double> embedding;
  final int faceCount;
  final String modelName;
  final String modelVersion;
  final double qualityScore;
  final String imageUrl;
}

class FaceAttendanceCandidate {
  const FaceAttendanceCandidate({
    required this.studentId,
    required this.confidence,
    this.rosterStudentId,
    this.faceProfileId,
    this.embeddingId,
    this.distance,
  });

  final String studentId;
  final String? rosterStudentId;
  final String? faceProfileId;
  final String? embeddingId;
  final double confidence;
  final double? distance;

  factory FaceAttendanceCandidate.fromJson(Map<String, dynamic> json) {
    return FaceAttendanceCandidate(
      studentId:
          json['studentId']?.toString() ??
          json['rosterStudentId']?.toString() ??
          '',
      rosterStudentId: json['rosterStudentId']?.toString(),
      faceProfileId:
          json['faceProfileId']?.toString() ??
          json['rosterStudentId']?.toString(),
      embeddingId: json['embeddingId']?.toString(),
      confidence: double.tryParse(json['confidence']?.toString() ?? '') ?? 0,
      distance: double.tryParse(json['distance']?.toString() ?? ''),
    );
  }
}

class FaceAttendanceCaptureResult {
  const FaceAttendanceCaptureResult({
    required this.result,
    required this.confidence,
    required this.candidates,
    this.detectedStudentId,
    this.logId,
  });

  final String result;
  final String? detectedStudentId;
  final String? logId;
  final double confidence;
  final List<FaceAttendanceCandidate> candidates;

  factory FaceAttendanceCaptureResult.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    return FaceAttendanceCaptureResult(
      result: json['result']?.toString() ?? 'UNKNOWN',
      detectedStudentId:
          json['detectedStudentId']?.toString() ??
          json['detectedRosterStudentId']?.toString(),
      logId: json['logId']?.toString(),
      confidence: double.tryParse(json['confidence']?.toString() ?? '') ?? 0,
      candidates: candidates is List
          ? candidates
                .whereType<Map<String, dynamic>>()
                .map(FaceAttendanceCandidate.fromJson)
                .toList()
          : const [],
    );
  }
}

class FaceEnrollmentResult {
  const FaceEnrollmentResult({
    required this.studentId,
    required this.schoolId,
    required this.sampleAccepted,
    required this.embeddingDimension,
    this.profileId,
    this.sampleId,
    this.embeddingId,
    this.profileStatus,
  });

  final String studentId;
  final String schoolId;
  final bool sampleAccepted;
  final int embeddingDimension;
  final String? profileId;
  final String? sampleId;
  final String? embeddingId;
  final String? profileStatus;

  factory FaceEnrollmentResult.fromJson(Map<String, dynamic> json) {
    return FaceEnrollmentResult(
      studentId:
          json['studentId']?.toString() ??
          json['rosterStudentId']?.toString() ??
          '',
      schoolId: json['schoolId']?.toString() ?? '',
      sampleAccepted:
          json['sampleAccepted'] == true ||
          json['enrollmentStatus']?.toString() == 'ACTIVE',
      embeddingDimension:
          int.tryParse(json['embeddingDimension']?.toString() ?? '') ?? 0,
      profileId:
          json['profileId']?.toString() ?? json['rosterStudentId']?.toString(),
      sampleId:
          json['sampleId']?.toString() ??
          json['primaryFaceSampleId']?.toString(),
      embeddingId: json['embeddingId']?.toString(),
      profileStatus:
          json['profileStatus']?.toString() ??
          json['enrollmentStatus']?.toString(),
    );
  }
}

class OfflineFaceTemplate {
  const OfflineFaceTemplate({
    required this.rosterStudentId,
    required this.embeddingId,
    required this.modelName,
    required this.modelVersion,
    required this.embedding,
    required this.qualityScore,
  });

  final String rosterStudentId;
  final String embeddingId;
  final String modelName;
  final String modelVersion;
  final List<double> embedding;
  final double qualityScore;

  factory OfflineFaceTemplate.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'];
    return OfflineFaceTemplate(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      embeddingId: json['embeddingId']?.toString() ?? '',
      modelName: json['modelName']?.toString() ?? 'InsightFace',
      modelVersion:
          json['modelVersion']?.toString() ?? 'buffalo_l-mobile-onnx-v1',
      embedding: rawEmbedding is List
          ? rawEmbedding
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList(growable: false)
          : const [],
      qualityScore:
          double.tryParse(json['qualityScore']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rosterStudentId': rosterStudentId,
      'embeddingId': embeddingId,
      'modelName': modelName,
      'modelVersion': modelVersion,
      'embedding': embedding,
      'qualityScore': qualityScore,
    };
  }
}
