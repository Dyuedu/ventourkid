class ParentLinkPrerequisitesModel {
  const ParentLinkPrerequisitesModel({
    required this.hasParentProfile,
    required this.hasPhoneNumber,
    this.message,
  });

  factory ParentLinkPrerequisitesModel.fromJson(Map<String, dynamic> json) {
    return ParentLinkPrerequisitesModel(
      hasParentProfile: json['hasParentProfile'] as bool? ?? false,
      hasPhoneNumber: json['hasPhoneNumber'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  final bool hasParentProfile;
  final bool hasPhoneNumber;
  final String? message;

  bool get canLink => hasParentProfile && hasPhoneNumber;
}

class TripLinkActivityModel {
  const TripLinkActivityModel({
    required this.operationPlanId,
    this.bookingId,
    this.schoolName,
    this.tourName,
    this.tourDate,
    this.parentPhoneMasked,
    this.pendingStudentCount = 0,
  });

  factory TripLinkActivityModel.fromJson(Map<String, dynamic> json) {
    return TripLinkActivityModel(
      operationPlanId: json['operationPlanId']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      schoolName: json['schoolName'] as String?,
      tourName: json['tourName'] as String?,
      tourDate: json['tourDate']?.toString(),
      parentPhoneMasked: json['parentPhoneMasked'] as String?,
      pendingStudentCount: json['pendingStudentCount'] as int? ?? 0,
    );
  }

  final String operationPlanId;
  final String? bookingId;
  final String? schoolName;
  final String? tourName;
  final String? tourDate;
  final String? parentPhoneMasked;
  final int pendingStudentCount;

  String get activityLinkKey =>
      [operationPlanId, bookingId].where((value) => value?.isNotEmpty == true).join(':');

  String get displayTourName =>
      tourName?.trim().isNotEmpty == true ? tourName!.trim() : 'Hoạt động trải nghiệm';
}

class TripLinkOtpResultModel {
  const TripLinkOtpResultModel({
    required this.rosterStudentId,
    this.parentPhoneMasked,
    this.ttlSeconds = 0,
  });

  factory TripLinkOtpResultModel.fromJson(Map<String, dynamic> json) {
    return TripLinkOtpResultModel(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      parentPhoneMasked: json['parentPhoneMasked'] as String?,
      ttlSeconds: json['ttlSeconds'] as int? ?? 0,
    );
  }

  final String rosterStudentId;
  final String? parentPhoneMasked;
  final int ttlSeconds;
}

class TripLinkStudentMatchRequest {
  const TripLinkStudentMatchRequest({
    this.identityNumber,
    this.fullName,
    this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    return {
      if (identityNumber != null && identityNumber!.trim().isNotEmpty)
        'identityNumber': identityNumber!.trim(),
      if (fullName != null && fullName!.trim().isNotEmpty)
        'fullName': fullName!.trim(),
      if (dateOfBirth != null && dateOfBirth!.trim().isNotEmpty)
        'dateOfBirth': dateOfBirth!.trim(),
    };
  }

  final String? identityNumber;
  final String? fullName;
  final String? dateOfBirth;
}
