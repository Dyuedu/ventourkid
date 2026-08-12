import 'package:intl/intl.dart';

import '../../../livestream/data/models/livestream_setup_models.dart';
import '../../domain/entities/parent_dashboard.dart';
import '../models/parent_dashboard_api_models.dart';

class ParentDashboardMapper {
  static ParentDashboardData mergeRemote({
    required ParentDashboardData base,
    LinkedChildModel? child,
    List<ParentChildSummary> children = const [],
    ParentCurrentTourModel? currentTour,
    List<ParentActiveLivestream> activeLivestreams = const [],
    List<ParentPostTourHistory> postTourHistory = const [],
  }) {
    if (child == null) {
      return base.copyWith(
        clearTrip: true,
        clearChild: true,
        children: children,
        postTourHistory: postTourHistory,
      );
    }

    final tourId = currentTour?.tourId;
    final hasLive =
        tourId != null &&
        activeLivestreams.any((session) => session.tourId == tourId);

    return base.copyWith(
      updatedLabel: 'Vừa cập nhật',
      child: mapChild(child),
      children: children,
      currentJourney: mapJourney(currentTour, child, base.currentJourney),
      clearTrip: currentTour == null,
      trip: currentTour == null
          ? null
          : mapTrip(
              currentTour: currentTour,
              rosterStudentId: child.rosterStudentId,
              fallback: base.trip,
              livestreamActive: hasLive,
            ),
      postTourHistory: postTourHistory,
    );
  }

  static ParentPostTourHistory mapTourHistoryRow(Map<String, dynamic> row) {
    final tourId = (row['tour_id'] ?? row['tourId'] ?? '').toString();
    final tourName = (row['tour_name'] ?? row['tourName'] ?? 'Chuyến tham quan')
        .toString();
    final dateRaw = row['date'] ?? row['desired_tour_date'];
    final attendance =
        (row['attendance_status'] ?? row['attendanceStatus'] ?? 'PENDING')
            .toString();
    final mediaCount = row['media_count'] ?? row['mediaCount'] ?? 0;
    final incidentCount = row['incident_count'] ?? row['incidentCount'] ?? 0;
    final daysRemaining =
        row['media_retention_days_remaining'] ??
        row['mediaRetentionDaysRemaining'];
    final showBanner =
        row['show_media_retention_banner'] == true ||
        row['showMediaRetentionBanner'] == true;
    final retentionLabel = showBanner && daysRemaining is num
        ? 'Ảnh tour còn ${daysRemaining.toInt()} ngày trước khi xóa'
        : 'Trong thời hạn xem lại sau tour';

    return ParentPostTourHistory(
      tourId: tourId,
      tourName: tourName,
      dateLabel: _formatDate(dateRaw?.toString()),
      retentionLabel: retentionLabel,
      attendanceSummary: _attendanceLabel(attendance),
      incidentSummary: '$incidentCount sự cố',
      mediaSummary: '$mediaCount ảnh/video đã duyệt',
      canSubmitFeedback: tourId.isNotEmpty,
      mediaRetentionDaysRemaining: daysRemaining is num
          ? daysRemaining.toInt()
          : null,
      showMediaRetentionBanner: showBanner,
    );
  }

  static String _attendanceLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return 'Có mặt';
      case 'ABSENT':
      case 'LATE':
        return 'Vắng';
      default:
        return status;
    }
  }

  static ParentChildSummary mapChild(LinkedChildModel child) {
    return ParentChildSummary(
      rosterStudentId: child.rosterStudentId,
      operationPlanId: child.operationPlanId,
      name: child.displayLabel,
      statusLabel: _tripLinkStatusLabel(child.tripLinkStatus),
      schoolName: child.schoolName ?? '—',
      className: child.className ?? child.grade ?? '—',
      studentCode: child.rosterStudentId.length > 8
          ? child.rosterStudentId.substring(0, 8)
          : child.rosterStudentId,
      dateOfBirth: _formatDate(child.dateOfBirth),
      medicalNote: child.medicalNotes?.trim().isNotEmpty == true
          ? child.medicalNotes!.trim()
          : 'Chưa có ghi chú y tế.',
      linkedAtLabel:
          'Liên kết tour: ${_tripLinkStatusLabel(child.tripLinkStatus)}',
    );
  }

  static ParentJourneySummary mapJourney(
    ParentCurrentTourModel? currentTour,
    LinkedChildModel? child,
    ParentJourneySummary fallback,
  ) {
    if (currentTour == null) {
      return ParentJourneySummary(
        name: child?.tourName ?? 'Chưa có chuyến đi active',
        statusLabel: 'Chưa diễn ra',
        remainingDistance: '—',
        estimatedArrival: '—',
        punctualityLabel: 'Theo dõi khi tour bắt đầu',
      );
    }

    return ParentJourneySummary(
      name: currentTour.tourName,
      statusLabel:
          currentTour.planStatus ?? currentTour.bookingStatus ?? 'ACTIVE',
      remainingDistance: fallback.remainingDistance,
      estimatedArrival: fallback.estimatedArrival,
      punctualityLabel: fallback.punctualityLabel,
    );
  }

  static ParentTripInfo mapTrip({
    required ParentCurrentTourModel currentTour,
    required String rosterStudentId,
    ParentTripInfo? fallback,
    required bool livestreamActive,
  }) {
    return ParentTripInfo(
      tourId: currentTour.tourId,
      rosterStudentId: rosterStudentId,
      tourName: currentTour.tourName,
      tourDate: _formatDate(currentTour.plannedDate),
      vehicleLabel: fallback?.vehicleLabel ?? '—',
      locationSummary:
          fallback?.locationSummary ??
          'Vị trí chi tiết sẽ hiển thị khi tour đang diễn ra.',
      currentCheckpoint:
          currentTour.currentCheckpointName?.trim().isNotEmpty == true
          ? currentTour.currentCheckpointName!.trim()
          : (fallback?.currentCheckpoint ?? 'Chưa có dữ liệu'),
      nextCheckpoint: currentTour.nextCheckpointName?.trim().isNotEmpty == true
          ? currentTour.nextCheckpointName!.trim()
          : (fallback?.nextCheckpoint ?? 'Chưa có dữ liệu'),
      attendanceLabel: fallback?.attendanceLabel ?? '—',
      attendanceTime: fallback?.attendanceTime ?? '—',
      approvedMediaCount: fallback?.approvedMediaCount ?? 0,
      livestreamActive: livestreamActive,
      contacts: fallback?.contacts ?? const [],
      schedule: fallback?.schedule ?? const [],
    );
  }

  static String _tripLinkStatusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
      case 'VERIFIED':
        return 'Đã liên kết với phụ huynh';
      case 'PENDING':
        return 'Chờ xác thực';
      case 'EXPIRED':
        return 'Đã hết hạn';
      default:
        return status ?? 'Đã liên kết';
    }
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }
}
