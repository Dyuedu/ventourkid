enum ParentQuickActionKind {
  linkChild,
  childProfile,
  documents,
  authorizations,
  tripInfo,
  incidents,
  mediaUpload,
  livestream,
  postTourHistory,
  media,
  newsfeed,
  trackingMap,
  aiAssistant,
  faceEnroll,
}

enum ParentAlertKind { confirmed, warning, location }

enum ParentDocumentStatusKind { ready, pending, missing }

enum ParentAuthorizationKind { face, media, livestream, tracker }

enum ParentAuthorizationStatus {
  authorized,
  notAuthorized,
  pending,
  notApplicable,
}

enum ParentScheduleStatus { completed, current, upcoming }

class ParentDashboardData {
  const ParentDashboardData({
    required this.updatedLabel,
    required this.notificationCount,
    required this.currentJourney,
    required this.quickActions,
    required this.recentAlerts,
    this.child,
    this.children = const [],
    this.documents = const [],
    this.authorizations = const [],
    this.trip,
    this.incidents = const [],
    this.mediaSubmissions = const [],
    this.postTourHistory = const [],
    this.pendingTripLinks = const [],
    this.isAccompanyingParent = false,
    this.schoolAllowsWelfareNote = false,
  });

  final String updatedLabel;
  final int notificationCount;
  final ParentJourneySummary currentJourney;
  final List<ParentQuickAction> quickActions;
  final List<ParentAlert> recentAlerts;
  final ParentChildSummary? child;
  final List<ParentChildSummary> children;
  final List<ParentDocumentStatus> documents;
  final List<ParentAuthorizationSummary> authorizations;
  final ParentTripInfo? trip;
  final List<ParentIncidentReport> incidents;
  final List<ParentMediaSubmission> mediaSubmissions;
  final List<ParentPostTourHistory> postTourHistory;
  final List<ParentPendingTripLink> pendingTripLinks;
  final bool isAccompanyingParent;
  final bool schoolAllowsWelfareNote;

  ParentDashboardData copyWith({
    String? updatedLabel,
    int? notificationCount,
    ParentJourneySummary? currentJourney,
    List<ParentQuickAction>? quickActions,
    List<ParentAlert>? recentAlerts,
    ParentChildSummary? child,
    bool clearChild = false,
    List<ParentChildSummary>? children,
    List<ParentDocumentStatus>? documents,
    List<ParentAuthorizationSummary>? authorizations,
    ParentTripInfo? trip,
    bool clearTrip = false,
    List<ParentIncidentReport>? incidents,
    List<ParentMediaSubmission>? mediaSubmissions,
    List<ParentPostTourHistory>? postTourHistory,
    List<ParentPendingTripLink>? pendingTripLinks,
    bool? isAccompanyingParent,
    bool? schoolAllowsWelfareNote,
  }) {
    return ParentDashboardData(
      updatedLabel: updatedLabel ?? this.updatedLabel,
      notificationCount: notificationCount ?? this.notificationCount,
      currentJourney: currentJourney ?? this.currentJourney,
      quickActions: quickActions ?? this.quickActions,
      recentAlerts: recentAlerts ?? this.recentAlerts,
      child: clearChild ? null : (child ?? this.child),
      children: children ?? this.children,
      documents: documents ?? this.documents,
      authorizations: authorizations ?? this.authorizations,
      trip: clearTrip ? null : (trip ?? this.trip),
      incidents: incidents ?? this.incidents,
      mediaSubmissions: mediaSubmissions ?? this.mediaSubmissions,
      postTourHistory: postTourHistory ?? this.postTourHistory,
      pendingTripLinks: pendingTripLinks ?? this.pendingTripLinks,
      isAccompanyingParent: isAccompanyingParent ?? this.isAccompanyingParent,
      schoolAllowsWelfareNote:
          schoolAllowsWelfareNote ?? this.schoolAllowsWelfareNote,
    );
  }
}

class ParentJourneySummary {
  const ParentJourneySummary({
    required this.name,
    required this.statusLabel,
    required this.remainingDistance,
    required this.estimatedArrival,
    required this.punctualityLabel,
  });

  final String name;
  final String statusLabel;
  final String remainingDistance;
  final String estimatedArrival;
  final String punctualityLabel;
}

class ParentQuickAction {
  const ParentQuickAction({required this.kind, required this.label});

  final ParentQuickActionKind kind;
  final String label;
}

class ParentAlert {
  const ParentAlert({
    required this.kind,
    required this.title,
    required this.timeLabel,
  });

  final ParentAlertKind kind;
  final String title;
  final String timeLabel;
}

class ParentChildSummary {
  const ParentChildSummary({
    this.rosterStudentId,
    this.operationPlanId,
    required this.name,
    required this.statusLabel,
    required this.schoolName,
    required this.className,
    required this.studentCode,
    required this.dateOfBirth,
    required this.medicalNote,
    required this.linkedAtLabel,
  });

  final String? rosterStudentId;
  final String? operationPlanId;
  final String name;
  final String statusLabel;
  final String schoolName;
  final String className;
  final String studentCode;
  final String dateOfBirth;
  final String medicalNote;
  final String linkedAtLabel;
}

class ParentDocumentStatus {
  const ParentDocumentStatus({
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.note,
    required this.reviewerLabel,
  });

  final String title;
  final ParentDocumentStatusKind status;
  final String statusLabel;
  final String note;
  final String reviewerLabel;
}

class ParentAuthorizationSummary {
  const ParentAuthorizationSummary({
    required this.kind,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.detail,
    required this.updatedByLabel,
  });

  final ParentAuthorizationKind kind;
  final String title;
  final ParentAuthorizationStatus status;
  final String statusLabel;
  final String detail;
  final String updatedByLabel;
}

class ParentTripInfo {
  const ParentTripInfo({
    this.tourId,
    this.rosterStudentId,
    required this.tourName,
    required this.tourDate,
    required this.vehicleLabel,
    required this.locationSummary,
    required this.currentCheckpoint,
    required this.nextCheckpoint,
    required this.attendanceLabel,
    required this.attendanceTime,
    required this.approvedMediaCount,
    required this.livestreamActive,
    required this.contacts,
    required this.schedule,
  });

  final String? tourId;
  final String? rosterStudentId;
  final String tourName;
  final String tourDate;
  final String vehicleLabel;
  final String locationSummary;
  final String currentCheckpoint;
  final String nextCheckpoint;
  final String attendanceLabel;
  final String attendanceTime;
  final int approvedMediaCount;
  final bool livestreamActive;
  final List<String> contacts;
  final List<ParentScheduleItem> schedule;
}

class ParentScheduleItem {
  const ParentScheduleItem({
    required this.time,
    required this.title,
    required this.status,
  });

  final String time;
  final String title;
  final ParentScheduleStatus status;
}

class ParentIncidentReport {
  const ParentIncidentReport({
    required this.type,
    required this.severityLabel,
    required this.timeLabel,
    required this.locationLabel,
    required this.statusLabel,
    required this.summary,
    required this.staffNote,
  });

  final String type;
  final String severityLabel;
  final String timeLabel;
  final String locationLabel;
  final String statusLabel;
  final String summary;
  final String staffNote;
}

class ParentMediaSubmission {
  const ParentMediaSubmission({
    required this.activityLabel,
    required this.statusLabel,
    required this.uploadedAtLabel,
    required this.moderationNote,
  });

  final String activityLabel;
  final String statusLabel;
  final String uploadedAtLabel;
  final String moderationNote;
}

class ParentPostTourHistory {
  const ParentPostTourHistory({
    required this.tourId,
    required this.tourName,
    required this.dateLabel,
    required this.retentionLabel,
    required this.attendanceSummary,
    required this.incidentSummary,
    required this.mediaSummary,
    this.canSubmitFeedback = true,
    this.mediaRetentionDaysRemaining,
    this.showMediaRetentionBanner = false,
  });

  final String tourId;
  final String tourName;
  final String dateLabel;
  final String retentionLabel;
  final String attendanceSummary;
  final String incidentSummary;
  final String mediaSummary;
  final bool canSubmitFeedback;
  final int? mediaRetentionDaysRemaining;
  final bool showMediaRetentionBanner;
}

/// Experience activity waiting for the parent to link a roster student (OTP).
class ParentPendingTripLink {
  const ParentPendingTripLink({
    required this.operationPlanId,
    this.bookingId,
    this.schoolName,
    this.tourName,
    this.tourDate,
    this.parentPhoneMasked,
    this.pendingStudentCount = 0,
  });

  final String operationPlanId;
  final String? bookingId;
  final String? schoolName;
  final String? tourName;
  final String? tourDate;
  final String? parentPhoneMasked;
  final int pendingStudentCount;

  String get activityLinkKey => [
    operationPlanId,
    if (bookingId != null && bookingId!.isNotEmpty) bookingId!,
  ].join(':');

  String get displayTourName =>
      tourName?.trim().isNotEmpty == true ? tourName!.trim() : 'Hoạt động trải nghiệm';
}
