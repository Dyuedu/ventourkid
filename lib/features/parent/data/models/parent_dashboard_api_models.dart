class LinkedChildModel {
  const LinkedChildModel({
    required this.rosterStudentId,
    required this.fullName,
    this.displayName,
    this.schoolName,
    this.className,
    this.grade,
    this.dateOfBirth,
    this.medicalNotes,
    this.tripLinkStatus,
    this.operationPlanId,
    this.tourName,
    this.plannedDate,
  });

  factory LinkedChildModel.fromJson(Map<String, dynamic> json) {
    return LinkedChildModel(
      rosterStudentId: json['rosterStudentId']?.toString() ?? '',
      fullName: json['fullName'] as String? ?? '',
      displayName: json['displayName'] as String?,
      schoolName: json['schoolName'] as String?,
      className: json['className'] as String?,
      grade: json['grade'] as String?,
      dateOfBirth: json['dateOfBirth']?.toString(),
      medicalNotes: json['medicalNotes'] as String?,
      tripLinkStatus: json['tripLinkStatus'] as String?,
      operationPlanId: json['operationPlanId']?.toString(),
      tourName: json['tourName'] as String?,
      plannedDate: json['plannedDate']?.toString(),
    );
  }

  final String rosterStudentId;
  final String fullName;
  final String? displayName;
  final String? schoolName;
  final String? className;
  final String? grade;
  final String? dateOfBirth;
  final String? medicalNotes;
  final String? tripLinkStatus;
  final String? operationPlanId;
  final String? tourName;
  final String? plannedDate;

  String get displayLabel =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : fullName;
}

class ParentCurrentTourModel {
  const ParentCurrentTourModel({
    required this.tourId,
    required this.tourName,
    this.planStatus,
    this.bookingStatus,
    this.plannedDate,
    this.tripLinkStatus,
    this.currentCheckpointName,
    this.nextCheckpointName,
  });

  factory ParentCurrentTourModel.fromJson(Map<String, dynamic> json) {
    return ParentCurrentTourModel(
      tourId: json['tour_id']?.toString() ?? json['tourId']?.toString() ?? '',
      tourName:
          json['tour_name'] as String? ??
          json['tourName'] as String? ??
          'Hoạt động trải nghiệm',
      planStatus:
          json['plan_status'] as String? ?? json['planStatus'] as String?,
      bookingStatus:
          json['booking_status'] as String? ?? json['bookingStatus'] as String?,
      plannedDate:
          json['planned_date']?.toString() ?? json['plannedDate']?.toString(),
      tripLinkStatus:
          json['trip_link_status'] as String? ??
          json['tripLinkStatus'] as String?,
      currentCheckpointName: json['current_checkpoint_name'] as String? ??
          json['currentCheckpointName'] as String?,
      nextCheckpointName: json['next_checkpoint_name'] as String? ??
          json['nextCheckpointName'] as String?,
    );
  }

  final String tourId;
  final String tourName;
  final String? planStatus;
  final String? bookingStatus;
  final String? plannedDate;
  final String? tripLinkStatus;
  final String? currentCheckpointName;
  final String? nextCheckpointName;

  bool get isEmpty => tourId.isEmpty;
}

class ParentConsentOtpModel {
  const ParentConsentOtpModel({
    required this.maskedPhone,
    required this.expiresInSeconds,
  });

  factory ParentConsentOtpModel.fromJson(Map<String, dynamic> json) =>
      ParentConsentOtpModel(
        maskedPhone:
            json['parentPhoneMasked']?.toString() ??
            json['maskedPhone']?.toString() ??
            'số điện thoại đã đăng ký',
        expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
      );

  final String maskedPhone;
  final int expiresInSeconds;
}
