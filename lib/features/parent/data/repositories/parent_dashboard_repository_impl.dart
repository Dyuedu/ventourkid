import '../../../livestream/data/datasources/livestream_remote_data_source.dart';
import '../../domain/entities/parent_dashboard.dart';
import '../../domain/repositories/parent_dashboard_repository.dart';
import '../datasources/parent_dashboard_local_data_source.dart';
import '../datasources/parent_dashboard_remote_data_source.dart';
import '../datasources/parent_link_remote_data_source.dart';
import '../mappers/parent_dashboard_mapper.dart';

class ParentDashboardRepositoryImpl implements ParentDashboardRepository {
  const ParentDashboardRepositoryImpl({
    required ParentDashboardLocalDataSource localDataSource,
    required ParentDashboardRemoteDataSource remoteDataSource,
    required LivestreamRemoteDataSource livestreamRemoteDataSource,
    required ParentLinkRemoteDataSource parentLinkRemoteDataSource,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _livestreamRemoteDataSource = livestreamRemoteDataSource,
       _parentLinkRemoteDataSource = parentLinkRemoteDataSource;

  final ParentDashboardLocalDataSource _localDataSource;
  final ParentDashboardRemoteDataSource _remoteDataSource;
  final LivestreamRemoteDataSource _livestreamRemoteDataSource;
  final ParentLinkRemoteDataSource _parentLinkRemoteDataSource;

  @override
  Future<ParentDashboardData> getDashboard({
    String? selectedRosterStudentId,
    String? selectedTourId,
  }) async {
    final base = await _localDataSource.getDashboard();
    final pendingTripLinks = await _loadPendingTripLinks();

    try {
      final children = await _remoteDataSource.getLinkedChildren();
      if (children.isEmpty) {
        return base.copyWith(
          clearTrip: true,
          clearChild: true,
          children: const [],
          recentAlerts: const [],
          documents: const [],
          authorizations: const [],
          incidents: const [],
          mediaSubmissions: const [],
          postTourHistory: const [],
          pendingTripLinks: pendingTripLinks,
          isAccompanyingParent: false,
          schoolAllowsWelfareNote: false,
        );
      }

      final selectedChild = children.firstWhere(
        (child) => child.rosterStudentId == selectedRosterStudentId,
        orElse: () => children.first,
      );
      final currentTour = await _remoteDataSource.getCurrentTour(
        rosterStudentId: selectedChild.rosterStudentId,
        tourId: selectedTourId,
      );
      final activeLivestreams = await _livestreamRemoteDataSource
          .getParentActiveLivestreams();

      List<ParentPostTourHistory> history = const [];
      try {
        final rawHistory = await _remoteDataSource.getTourHistory(
          rosterStudentId: selectedChild.rosterStudentId,
        );
        history = rawHistory
            .map(ParentDashboardMapper.mapTourHistoryRow)
            .where((item) => item.tourId.isNotEmpty)
            .toList();
      } catch (_) {
        history = const [];
      }

      // Grace window: linked child still has plan id after COMPLETED but history may lag.
      final planId = selectedChild.operationPlanId?.trim();
      if (currentTour == null &&
          planId != null &&
          planId.isNotEmpty &&
          !history.any((h) => h.tourId == planId)) {
        history = [
          ParentPostTourHistory(
            tourId: planId,
            tourName: selectedChild.tourName?.trim().isNotEmpty == true
                ? selectedChild.tourName!.trim()
                : 'Chuyến tham quan vừa kết thúc',
            dateLabel: '—',
            retentionLabel: 'Trong thời hạn xem lại sau tour',
            attendanceSummary: '—',
            incidentSummary: '—',
            mediaSummary: '—',
            canSubmitFeedback: true,
          ),
          ...history,
        ];
      }

      return ParentDashboardMapper.mergeRemote(
        base: base,
        child: selectedChild,
        children: children.map(ParentDashboardMapper.mapChild).toList(),
        currentTour: currentTour,
        activeLivestreams: activeLivestreams,
        postTourHistory: history,
      ).copyWith(pendingTripLinks: pendingTripLinks);
    } catch (_) {
      return base.copyWith(
        clearTrip: true,
        clearChild: true,
        children: const [],
        recentAlerts: const [],
        documents: const [],
        authorizations: const [],
        incidents: const [],
        mediaSubmissions: const [],
        postTourHistory: const [],
        pendingTripLinks: pendingTripLinks,
        isAccompanyingParent: false,
        schoolAllowsWelfareNote: false,
      );
    }
  }

  Future<List<ParentPendingTripLink>> _loadPendingTripLinks() async {
    try {
      final candidates = await _parentLinkRemoteDataSource
          .getTripLinkCandidates();
      return candidates
          .map(
            (item) => ParentPendingTripLink(
              operationPlanId: item.operationPlanId,
              bookingId: item.bookingId,
              schoolName: item.schoolName,
              tourName: item.tourName,
              tourDate: item.tourDate,
              parentPhoneMasked: item.parentPhoneMasked,
              pendingStudentCount: item.pendingStudentCount,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
