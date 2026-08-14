import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../shared/i18n/language_switcher.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/app_bootstrap_splash.dart';
import '../../../attendance/domain/entities/offline_attendance.dart';

enum GuideDashboardRole { guide, teacher }

enum _TourListTab { active, upcoming, history }

class GuideDashboardPage extends ConsumerStatefulWidget {
  const GuideDashboardPage({super.key, this.role = GuideDashboardRole.guide});

  final GuideDashboardRole role;

  @override
  ConsumerState<GuideDashboardPage> createState() => _GuideDashboardPageState();
}

class _GuideDashboardPageState extends ConsumerState<GuideDashboardPage> {
  List<AttendanceTour> _activeTours = const [];
  List<AttendanceTour> _upcomingTours = const [];
  List<AttendanceTour> _historyTours = const [];
  final Map<_TourListTab, String?> _selectedByTab = {};
  _TourListTab _tab = _TourListTab.active;
  bool _loadingTours = true;
  String? _tourError;
  bool _showMoreActions = false;
  Timer? _graceTicker;

  /// Bumps UI so completed grace countdown re-renders.
  int _graceTick = 0;

  @override
  void initState() {
    super.initState();
    _graceTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _graceTick++);
      final tour = _activeTour;
      if (tour != null &&
          tour.isCompleted &&
          tour.activeGraceRemaining == Duration.zero) {
        _loadTours();
      }
    });
    Future.microtask(() async {
      await ref.read(notificationRealtimeProvider.notifier).start();
      await _loadTours();
    });
  }

  @override
  void dispose() {
    _graceTicker?.cancel();
    super.dispose();
  }

  List<AttendanceTour> get _tours => switch (_tab) {
    _TourListTab.active => _activeTours,
    _TourListTab.upcoming => _upcomingTours,
    _TourListTab.history => _historyTours,
  };

  Future<void> _loadTours() async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    setState(() {
      _loadingTours = true;
      _tourError = null;
    });
    try {
      final results = await Future.wait([
        repository.refreshTours(),
        repository.listUpcomingTours(days: 30),
        repository.listTourHistory(days: 30),
      ]);
      if (!mounted) return;
      final previousActiveId = _selectedByTab[_TourListTab.active];
      setState(() {
        _activeTours = results[0].where((tour) => !tour.isCompleted).toList();
        _upcomingTours = results[1];
        _historyTours = results[2];
        for (final tab in _TourListTab.values) {
          final list = switch (tab) {
            _TourListTab.active => _activeTours,
            _TourListTab.upcoming => _upcomingTours,
            _TourListTab.history => _historyTours,
          };
          _selectedByTab[tab] = _tourOrFirst(_selectedByTab[tab], list);
        }
        // Just closed: leave Đang chạy immediately and keep the same tour on Đã xong.
        if (_tab == _TourListTab.active &&
            previousActiveId != null &&
            _activeTours.every((tour) => tour.tourId != previousActiveId) &&
            _historyTours.any((tour) => tour.tourId == previousActiveId)) {
          _tab = _TourListTab.history;
          _selectedByTab[_TourListTab.history] = previousActiveId;
        }
      });
    } on Object catch (error) {
      final cachedTours = await repository.getCachedTours();
      if (!mounted) return;
      setState(() {
        _activeTours = cachedTours.where((tour) => !tour.isCompleted).toList();
        _selectedByTab[_TourListTab.active] = _tourOrFirst(
          _selectedByTab[_TourListTab.active],
          cachedTours,
        );
        _tourError = cachedTours.isEmpty
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Đang dùng danh sách tour đã lưu trên máy (tab Đang chạy).';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingTours = false);
      }
    }
  }

  String? get _activeTourId =>
      _selectedByTab[_tab] ?? (_tours.isEmpty ? null : _tours.first.tourId);

  AttendanceTour? get _activeTour {
    final tourId = _activeTourId;
    if (tourId == null || tourId.isEmpty) return null;
    for (final tour in _tours) {
      if (tour.tourId == tourId) return tour;
    }
    return null;
  }

  bool get _isTeacher => widget.role == GuideDashboardRole.teacher;

  String get _dashboardTitle => _isTeacher ? 'Điều khiển GV' : 'Điều khiển HDV';

  String get _newsfeedTitle =>
      _isTeacher ? 'Bảng tin giáo viên' : 'Bảng tin hướng dẫn viên';

  String get _newsfeedActor => _isTeacher ? 'Giáo viên' : 'Hướng dẫn viên';

  String get _tourSectionLabel => switch (_tab) {
    _TourListTab.active => _isTeacher ? 'Tour đang chạy' : 'Tour đang quản lý',
    _TourListTab.upcoming => 'Tour sắp tới (30 ngày)',
    _TourListTab.history => 'Lịch sử tour (30 ngày)',
  };

  String get _noTourMessage => switch (_tab) {
    _TourListTab.active =>
      _isTeacher
          ? 'Chưa có tour đang chạy hôm nay.'
          : 'Chưa có tour đang chạy. Xem tab Sắp tới hoặc Đã xong.',
    _TourListTab.upcoming => 'Chưa có tour sắp tới trong 30 ngày.',
    _TourListTab.history => 'Chưa có tour hoàn tất trong 30 ngày gần đây.',
  };

  @override
  Widget build(BuildContext context) {
    final unreadNotifications = ref
        .watch(notificationRealtimeProvider)
        .unreadCount;
    final tour = _activeTour;

    if (_loadingTours &&
        _activeTours.isEmpty &&
        _upcomingTours.isEmpty &&
        _historyTours.isEmpty) {
      return const AppBootstrapHold();
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: Text(_dashboardTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: LanguageSwitcher(onChanged: () => unawaited(_loadTours())),
          ),
          IconButton(
            tooltip: 'Thông báo',
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              backgroundColor: AppTheme.accentOrange,
              label: Text(
                unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Icon(Iconsax.notification),
            ),
            onPressed: () async {
              await context.push('/notifications');
            },
          ),
          IconButton(
            tooltip: 'Hồ sơ',
            icon: const Icon(Iconsax.profile_circle),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await Future.wait([
            _loadTours(),
            ref.read(notificationRealtimeProvider.notifier).refreshUnread(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTourTabs(),
              const SizedBox(height: 16),
              _GuideSectionHeader(
                title: _tourSectionLabel,
                subtitle: tour == null
                    ? null
                    : switch (_tab) {
                        _TourListTab.active =>
                          'Thao tác bên dưới áp dụng cho tour đang chọn.',
                        _TourListTab.upcoming =>
                          'Chỉ chuẩn bị trước ngày đi — điểm danh / vận hành khóa đến ngày tour.',
                        _TourListTab.history =>
                          'Chỉ xem lại — thao tác vận hành đã khóa.',
                      },
              ),
              const SizedBox(height: 12),
              _buildTourHero(),
              if (_tourError != null && _activeTours.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _tourError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _GuideSectionHeader(
                title: 'Thao tác chính',
                subtitle: switch (_tab) {
                  _TourListTab.upcoming =>
                    'Có thể xem lịch trình / đăng ký khuôn mặt. Điểm danh và thao tác vận hành khóa đến ngày tour.',
                  _TourListTab.history =>
                    'Tour đã xong: chỉ xem lại / đánh giá nếu có.',
                  _TourListTab.active =>
                    'Ưu tiên dùng khi đang điều hành tour.',
                },
              ),
              const SizedBox(height: 12),
              _buildPrimaryActions(
                tour != null,
              ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 20),
              _buildMoreActions(tour != null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourTabs() {
    Widget chip(_TourListTab tab, String label, int count) {
      final selected = _tab == tab;
      return Expanded(
        child: Material(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: () => setState(() => _tab = tab),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.neutral200,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_TourListTab.upcoming, 'Sắp tới', _upcomingTours.length),
        const SizedBox(width: 8),
        chip(_TourListTab.active, 'Đang chạy', _activeTours.length),
        const SizedBox(width: 8),
        chip(_TourListTab.history, 'Đã xong', _historyTours.length),
      ],
    );
  }

  Widget _buildTourHero() {
    if (_loadingTours) {
      return Container(
        height: 132,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: const Center(
          child: SizedBox(
            width: 140,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        ),
      );
    }

    if (_tours.isEmpty) {
      return _EmptyTourCard(
        message: _tourError ?? _noTourMessage,
        onRetry: _loadTours,
      );
    }

    final tour = _activeTour!;
    final canSwitch = _tours.length > 1;
    final meta = [
      if (tour.schoolName != null && tour.schoolName!.trim().isNotEmpty)
        tour.schoolName!,
      if (tour.tourDate != null)
        '${tour.tourDate!.day}/${tour.tourDate!.month}/${tour.tourDate!.year}',
    ].join(' · ');

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: canSwitch ? _openTourSwitcher : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
            boxShadow: AppTheme.shadowMd,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primarySoft.withValues(alpha: 0.55),
                AppTheme.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(
                      label: tour.statusLabelVi,
                      completed: tour.isCompleted,
                    ),
                    const Spacer(),
                    if (canSwitch)
                      TextButton.icon(
                        onPressed: _openTourSwitcher,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Đổi tour'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tour.tourName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (tour.isCompleted || _tab == _TourListTab.history) ...[
                  const SizedBox(height: 6),
                  Text(
                    // Rebuild driven by [_graceTick] timer so remaining time shrinks.
                    _tab == _TourListTab.history
                        ? tour.historyRetentionLabelVi
                        : tour.activeGraceLabelVi,
                    key: ValueKey('grace-$_graceTick-${tour.tourId}'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (_tab == _TourListTab.upcoming) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tour sắp tới · thao tác vận hành khóa đến ngày đi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${tour.rosterCount} học sinh',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canSwitch) ...[
                      const Spacer(),
                      Text(
                        '${_tours.length} tour',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(bool hasTour) {
    final completed =
        _activeTour?.isCompleted == true || _tab == _TourListTab.history;
    final upcoming = _tab == _TourListTab.upcoming;
    final runEnabled = hasTour && !completed && !upcoming;

    bool enabledFor(_ActionItem item) {
      if (!hasTour) return false;
      // Upcoming: chỉ mở prep (face enroll) + xem lịch trình; vận hành khóa.
      if (upcoming) return item.availableWhenUpcoming;
      // Post-tour: thư viện / Đóng tour / feedback xem được; vận hành mới vẫn khóa.
      if (completed) return item.availableWhenCompleted || !item.operational;
      if (item.operational) return runEnabled;
      return hasTour;
    }

    String disabledMessage(_ActionItem item) {
      if (!hasTour) return _noTourMessage;
      if (upcoming) {
        return 'Tour sắp tới — chưa tới ngày đi nên không mở điểm danh / vận hành. '
            'Có thể xem lịch trình hoặc đăng ký khuôn mặt để chuẩn bị.';
      }
      return 'Tour đã hoàn tất — thao tác vận hành đã khóa. Mở “Đóng tour” để xem lại.';
    }

    final actions = [
      if (widget.role == GuideDashboardRole.teacher && completed)
        _ActionItem(
          title: 'Đánh giá chuyến đi',
          subtitle: 'Gửi đánh giá sau khi tour đã đóng (1–5 sao)',
          icon: Icons.star_rounded,
          accent: AppTheme.accentOrange,
          onTap: () => _openTeacherFeedback(context),
          availableWhenCompleted: true,
          emphasized: true,
        ),
      if (widget.role == GuideDashboardRole.teacher)
        _ActionItem(
          title: 'Đăng ký khuôn mặt',
          subtitle: completed
              ? 'Tour đã hoàn tất — không còn đăng ký khuôn mặt'
              : upcoming
              ? 'Chuẩn bị trước ngày đi (trong cửa sổ prep)'
              : 'HS đã đồng thuận, còn thiếu mặt trên xe bạn',
          icon: Icons.face_retouching_natural_rounded,
          accent: AppTheme.primary,
          onTap: () => _openFaceEnroll(context, ref),
          operational: true,
          availableWhenUpcoming: true,
        ),
      _ActionItem(
        title: 'Quản lý lịch trình',
        subtitle: completed
            ? 'Tour đã hoàn tất — thao tác lịch trình đã khóa'
            : upcoming
            ? 'Xem kế hoạch trước ngày đi (chưa điểm danh / chốt)'
            : 'Đưa đón, điểm dừng và tiến độ',
        icon: Iconsax.map,
        accent: AppTheme.primary,
        onTap: () => _openTourScopedRoute(
          context,
          '/guide/itinerary',
          prep: upcoming,
        ),
        operational: true,
        availableWhenUpcoming: true,
      ),
      _ActionItem(
        title: 'Ảnh chuyến đi',
        subtitle: completed
            ? 'Chỉ xem thư viện — tour đã hoàn tất (không chụp/quay mới)'
            : upcoming
            ? 'Khóa đến ngày đi — media khi tour đang chạy'
            : 'Xem và tải media tour',
        icon: Iconsax.gallery,
        accent: const Color(0xFF1D4ED8),
        onTap: () => _openTourScopedRoute(
          context,
          '/media/timeline',
          readOnly: completed,
        ),
        operational: true,
        availableWhenCompleted: true,
      ),
      _ActionItem(
        title: 'Dị ứng thực phẩm',
        subtitle: upcoming
            ? 'Kiểm tra lưu ý an toàn theo xe trước ngày đi'
            : 'Danh sách học sinh dị ứng trên xe bạn phụ trách',
        icon: Icons.restaurant_menu_rounded,
        accent: const Color(0xFFB45309),
        onTap: () {
          final tour = _activeTour;
          if (tour != null) {
            context.push(Uri(
              path: '/field/food-allergy-alerts',
              queryParameters: {
                'tourId': tour.tourId,
                'tourName': tour.tourName,
              },
            ).toString());
          }
        },
        availableWhenUpcoming: true,
      ),
      _ActionItem(
        title: 'Theo dõi',
        subtitle: completed
            ? 'Xem lại vị trí xe và học sinh GPS của tour'
            : upcoming
            ? 'Khóa đến ngày đi — GPS khi tour đang chạy'
            : 'Xe đang đi đâu · học sinh GPS trên bản đồ',
        icon: Iconsax.location,
        accent: const Color(0xFF0F766E),
        onTap: () {
          final tourId = _activeTourId;
          if (tourId != null && tourId.isNotEmpty) {
            context.push('/tracking/$tourId');
          } else {
            context.push('/tracking');
          }
        },
        operational: true,
      ),
      _ActionItem(
        title: 'Báo cáo sự cố',
        subtitle: completed
            ? 'Tour đã hoàn tất — không còn tạo báo cáo sự cố mới'
            : upcoming
            ? 'Khóa đến ngày đi — sự cố khi đang vận hành'
            : 'Ghi nhận và theo dõi sự cố',
        icon: Iconsax.warning_2,
        accent: const Color(0xFFEA580C),
        onTap: () => _openTourScopedRoute(
          context,
          '/incident/list',
          readOnly: completed,
        ),
        // Locked after COMPLETED / on upcoming: field reporting is run-day only.
        operational: true,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _PrimaryActionTile(
            item: actions[i],
            enabled: enabledFor(actions[i]),
            onDisabledTap: () =>
                _showMessage(context, disabledMessage(actions[i])),
          ),
          if (i < actions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildMoreActions(bool hasTour) {
    final completed =
        _activeTour?.isCompleted == true || _tab == _TourListTab.history;
    final upcoming = _tab == _TourListTab.upcoming;
    final more = [
      _ActionItem(
        title: 'Bảng tin',
        subtitle: 'Cập nhật hoạt động tour',
        icon: Icons.newspaper_outlined,
        accent: AppTheme.cta,
        onTap: () => _openNewsfeed(context),
      ),
      _ActionItem(
        title: 'Trợ lý AI',
        subtitle: 'Hỏi đáp hỗ trợ điều hành',
        icon: Iconsax.message_question,
        accent: const Color(0xFF1E40AF),
        onTap: () => context.push('/ai-assistant'),
      ),
      _ActionItem(
        title: 'Đóng tour',
        subtitle: upcoming
            ? 'Chỉ mở khi tour đang chạy / đã hoàn tất'
            : completed
            ? 'Xem checklist đã khóa (chỉ đọc)'
            : 'Hoàn tất và khóa thao tác tour',
        icon: Icons.flag_outlined,
        accent: AppTheme.cta,
        onTap: () => _openTourScopedRoute(context, '/closing'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: () => setState(() => _showMoreActions = !_showMoreActions),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      _showMoreActions
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showMoreActions
                              ? 'Ẩn thao tác phụ'
                              : 'Thêm thao tác',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Bảng tin, trợ lý AI, đóng tour',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                for (var i = 0; i < more.length; i++) ...[
                  _PrimaryActionTile(
                    item: more[i],
                    enabled:
                        more[i].title == 'Trợ lý AI' ||
                        (hasTour &&
                            !(upcoming && more[i].title == 'Đóng tour')),
                    onDisabledTap: () => _showMessage(
                      context,
                      upcoming && more[i].title == 'Đóng tour'
                          ? 'Tour sắp tới chưa chạy — đóng tour khi đang vận hành.'
                          : _noTourMessage,
                    ),
                    compact: true,
                  ),
                  if (i < more.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          crossFadeState: _showMoreActions
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: AppTheme.motionNormal,
        ),
      ],
    );
  }

  Future<void> _openTourSwitcher() async {
    if (_tours.length <= 1) return;
    final selected = await showModalBottomSheet<AttendanceTour>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn tour',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thao tác nghiệp vụ sẽ theo tour bạn chọn.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _tours.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final tour = _tours[index];
                      final selected = tour.tourId == _activeTourId;
                      final meta = [
                        if (tour.schoolName != null) tour.schoolName!,
                        if (tour.tourDate != null)
                          '${tour.tourDate!.day}/${tour.tourDate!.month}/${tour.tourDate!.year}',
                      ].join(' · ');
                      return Material(
                        color: selected
                            ? AppTheme.primarySoft.withValues(alpha: 0.55)
                            : AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.neutral200,
                            ),
                          ),
                          title: Text(
                            tour.tourName,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: meta.isEmpty
                              ? null
                              : Text(
                                  meta,
                                  style: const TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(tour),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedByTab[_tab] = selected.tourId);
  }

  Future<void> _openTourScopedRoute(
    BuildContext context,
    String route, {
    bool readOnly = false,
    bool prep = false,
  }) async {
    final tourId = _activeTourId;
    if (tourId == null || tourId.isEmpty) {
      _showMessage(context, _noTourMessage);
      return;
    }
    final uri = Uri(
      path: route,
      queryParameters: {
        'tourId': tourId,
        if (readOnly) 'readOnly': '1',
        if (prep) 'prep': '1',
      },
    );
    await context.push(uri.toString());
    if (!mounted) return;
    if (route == '/closing') {
      await _loadTours();
    }
  }

  void _openTeacherFeedback(BuildContext context) {
    final tour = _activeTour;
    if (tour == null || tour.tourId.isEmpty) {
      _showMessage(context, _noTourMessage);
      return;
    }
    if (!tour.isCompleted && _tab != _TourListTab.history) {
      _showMessage(
        context,
        'Chỉ đánh giá sau khi tour đã hoàn tất.',
      );
      return;
    }
    final uri = Uri(
      path: '/teacher/feedback',
      queryParameters: {
        'tourId': tour.tourId,
        if (tour.tourName.trim().isNotEmpty) 'tourName': tour.tourName,
      },
    );
    context.push(uri.toString());
  }

  Future<void> _openFaceEnroll(BuildContext context, WidgetRef ref) async {
    final tour = _activeTour;
    if (tour == null || tour.tourId.isEmpty) {
      _showMessage(context, _noTourMessage);
      return;
    }
    try {
      if (widget.role == GuideDashboardRole.teacher) {
        await _openTeacherNeedsEnroll(context, ref, tour);
        return;
      }
      final students = await ref
          .read(offlineAttendanceRepositoryProvider)
          .refreshStudents(tour.tourId);
      if (!context.mounted) return;
      if (students.isEmpty) {
        _showMessage(context, 'Xe của bạn chưa có danh sách học sinh.');
        return;
      }
      final selected = await _pickStudentSheet(
        context,
        students
            .map(
              (s) => _FaceEnrollPickItem(
                rosterStudentId: s.rosterStudentId,
                fullName: s.fullName,
                subtitle: s.className ?? 'Học sinh trên xe',
              ),
            )
            .toList(growable: false),
      );
      if (!context.mounted || selected == null) return;
      _openFaceEnrollForStudent(context, tour, selected);
    } on Object catch (error) {
      // Nuốt lỗi khiến mọi sự cố đều thành một câu chung, lỗi thật chỉ nằm trong log backend.
      if (context.mounted) {
        _showMessage(
          context,
          'Không thể tải danh sách học sinh: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _openTeacherNeedsEnroll(
    BuildContext context,
    WidgetRef ref,
    AttendanceTour tour,
  ) async {
    try {
      final students = await ref
          .read(faceRemoteDataSourceProvider)
          .listStudentsNeedingEnroll(tour.tourId);
      if (!context.mounted) return;
      if (students.isEmpty) {
        _showMessage(
          context,
          'Không còn học sinh nào trên xe bạn đã đồng thuận nhưng chưa có khuôn mặt.',
        );
        return;
      }
      final selected = await _pickStudentSheet(
        context,
        students
            .map((s) {
              final parts = <String>[
                if (s.className != null && s.className!.trim().isNotEmpty)
                  s.className!.trim(),
                if (s.vehicleLabel != null && s.vehicleLabel!.trim().isNotEmpty)
                  s.vehicleLabel!.trim(),
              ];
              return _FaceEnrollPickItem(
                rosterStudentId: s.rosterStudentId,
                fullName: s.fullName,
                subtitle: parts.isEmpty
                    ? 'Cần đăng ký khuôn mặt'
                    : parts.join(' · '),
              );
            })
            .toList(growable: false),
        title: 'Còn thiếu khuôn mặt (${students.length})',
      );
      if (!context.mounted || selected == null) return;
      _openFaceEnrollForStudent(context, tour, selected);
    } on Object catch (error) {
      if (!context.mounted) return;
      final text = error.toString();
      if (text.contains('FACE-TEACHER-SCOPE-001')) {
        _showMessage(
          context,
          'Bạn chưa được phân quyền đăng ký khuôn mặt trên tour này.',
        );
        return;
      }
      _showMessage(context, 'Không thể tải danh sách học sinh cần đăng ký.');
    }
  }

  Future<_FaceEnrollPickItem?> _pickStudentSheet(
    BuildContext context,
    List<_FaceEnrollPickItem> students, {
    String title = 'Chọn học sinh',
  }) {
    return showModalBottomSheet<_FaceEnrollPickItem>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: students.length + 1,
          separatorBuilder: (context, index) =>
              index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
          itemBuilder: (_, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            final student = students[index - 1];
            return ListTile(
              leading: const Icon(Icons.face_retouching_natural_rounded),
              title: Text(student.fullName),
              subtitle: Text(student.subtitle),
              onTap: () => Navigator.of(sheetContext).pop(student),
            );
          },
        ),
      ),
    );
  }

  void _openFaceEnrollForStudent(
    BuildContext context,
    AttendanceTour tour,
    _FaceEnrollPickItem student,
  ) {
    context.push(
      '/face-enroll',
      extra: {
        'studentId': student.rosterStudentId,
        'schoolId': tour.schoolId ?? '',
        'operationPlanId': tour.tourId,
        'studentName': student.fullName,
      },
    );
  }

  void _openNewsfeed(BuildContext context) {
    final tourId = _activeTourId;
    if (tourId == null || tourId.isEmpty) {
      _showMessage(context, _noTourMessage);
      return;
    }
    final uri = Uri(
      path: '/newsfeed',
      queryParameters: {
        'tourId': tourId,
        'title': _newsfeedTitle,
        'actor': _newsfeedActor,
      },
    );
    context.push(uri.toString());
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _tourOrFirst(String? tourId, List<AttendanceTour> tours) {
  if (tourId != null && tours.any((tour) => tour.tourId == tourId)) {
    return tourId;
  }
  return tours.isEmpty ? null : tours.first.tourId;
}

class _ActionItem {
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.operational = false,
    this.availableWhenCompleted = false,
    this.availableWhenUpcoming = false,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  /// When true, action is locked after tour COMPLETED (unless [availableWhenCompleted]).
  final bool operational;
  /// When true, stays tappable (full opacity) on completed / history tours.
  final bool availableWhenCompleted;
  /// When true, stays tappable on upcoming (prep-only) tours.
  final bool availableWhenUpcoming;
  /// Stronger CTA styling so it does not look like a locked tile.
  final bool emphasized;
}

class _FaceEnrollPickItem {
  const _FaceEnrollPickItem({
    required this.rosterStudentId,
    required this.fullName,
    required this.subtitle,
  });

  final String rosterStudentId;
  final String fullName;
  final String subtitle;
}

class _PrimaryActionTile extends StatelessWidget {
  const _PrimaryActionTile({
    required this.item,
    required this.enabled,
    required this.onDisabledTap,
    this.compact = false,
  });

  final _ActionItem item;
  final bool enabled;
  final VoidCallback onDisabledTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final emphasized = item.emphasized && enabled;
    return Material(
      color: emphasized
          ? item.accent.withValues(alpha: 0.10)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: enabled ? item.onTap : onDisabledTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: emphasized
                  ? item.accent.withValues(alpha: 0.45)
                  : AppTheme.neutral200,
              width: emphasized ? 1.5 : 1,
            ),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: compact ? 12 : 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 40 : 46,
                    height: compact ? 40 : 46,
                    decoration: BoxDecoration(
                      color: item.accent
                          .withValues(alpha: emphasized ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(item.icon, color: item.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    emphasized
                        ? Icons.arrow_forward_rounded
                        : Icons.chevron_right_rounded,
                    color: emphasized ? item.accent : AppTheme.neutral500,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.completed = false});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final bg = completed ? const Color(0xFF15803D) : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyTourCard extends StatelessWidget {
  const _EmptyTourCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.route_outlined, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

class _GuideSectionHeader extends StatelessWidget {
  const _GuideSectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            color: AppTheme.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
