import '../../domain/entities/parent_dashboard.dart';

abstract interface class ParentDashboardLocalDataSource {
  Future<ParentDashboardData> getDashboard();
}

class ParentDashboardLocalDataSourceImpl
    implements ParentDashboardLocalDataSource {
  const ParentDashboardLocalDataSourceImpl();

  static const _emptyDashboard = ParentDashboardData(
    updatedLabel: 'Chưa có dữ liệu mới',
    notificationCount: 0,
    currentJourney: ParentJourneySummary(
      name: 'Không có tour nào đang diễn ra',
      statusLabel: 'Không có tour',
      remainingDistance: '--',
      estimatedArrival: '--',
      punctualityLabel: 'Hệ thống sẽ cập nhật khi có tour đang diễn ra.',
    ),
    quickActions: [
      ParentQuickAction(
        kind: ParentQuickActionKind.newsfeed,
        label: 'Bảng tin',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.linkChild,
        label: 'Liên kết con',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.childProfile,
        label: 'Hồ sơ con',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.documents,
        label: 'Giấy tờ',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.authorizations,
        label: 'Ủy quyền',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.tripInfo,
        label: 'Chuyến đi',
      ),
      ParentQuickAction(kind: ParentQuickActionKind.incidents, label: 'Sự cố'),
      ParentQuickAction(
        kind: ParentQuickActionKind.trackingMap,
        label: 'Theo dõi',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.mediaUpload,
        label: 'Gửi ảnh/video',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.livestream,
        label: 'Livestream',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.postTourHistory,
        label: 'Sau tour',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.media,
        label: 'Ảnh chuyến đi',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.aiAssistant,
        label: 'Trợ lý Ventour',
      ),
      ParentQuickAction(
        kind: ParentQuickActionKind.faceEnroll,
        label: 'Đăng ký khuôn mặt',
      ),
    ],
    recentAlerts: [],
    children: [],
    documents: [],
    authorizations: [],
    incidents: [],
    mediaSubmissions: [],
    postTourHistory: [],
    isAccompanyingParent: false,
    schoolAllowsWelfareNote: false,
  );

  @override
  Future<ParentDashboardData> getDashboard() async => _emptyDashboard;
}
