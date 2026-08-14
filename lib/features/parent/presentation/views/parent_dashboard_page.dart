import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../shared/i18n/language_switcher.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_bootstrap_splash.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../../face_attendance/presentation/views/parent_face_enroll_page.dart';
import '../../../consent/presentation/trip_consent_page.dart';
import '../../../livestream/presentation/widgets/parent_livestream_picker.dart';
import '../../domain/entities/parent_dashboard.dart';
import '../utils/parent_quick_action_ui.dart';
import '../widgets/parent_link_child_flow.dart';
import 'parent_more_actions_page.dart';

class ParentDashboardPage extends ConsumerStatefulWidget {
  const ParentDashboardPage({
    super.key,
    this.initialRosterStudentId,
    this.initialTourId,
  });

  final String? initialRosterStudentId;
  final String? initialTourId;

  @override
  ConsumerState<ParentDashboardPage> createState() =>
      _ParentDashboardPageState();
}

class _ParentDashboardPageState extends ConsumerState<ParentDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(notificationRealtimeProvider.notifier).start();
      final rosterId = widget.initialRosterStudentId?.trim();
      final tourId = widget.initialTourId?.trim();
      if ((rosterId != null && rosterId.isNotEmpty) ||
          (tourId != null && tourId.isNotEmpty)) {
        if (!mounted) return;
        await ref.read(parentDashboardViewModelProvider.notifier).load(
              selectedRosterStudentId: rosterId,
              selectedTourId: tourId,
            );
      }
    });
  }

  String? _resolveTourId(ParentDashboardData data) {
    final tourId = data.trip?.tourId;
    if (tourId == null || tourId.isEmpty) return null;
    return tourId;
  }

  Uri? _mediaTimelineUri(ParentDashboardData data) {
    final tourId = _resolveTourId(data);
    if (tourId == null) return null;
    final child = data.child;
    final studentId = child?.rosterStudentId?.trim();
    final studentName = child?.name.trim();
    return Uri(
      path: '/media/timeline',
      queryParameters: {
        'tourId': tourId,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (studentName != null && studentName.isNotEmpty)
          'studentName': studentName,
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(authViewModelProvider.notifier).logout();
    if (context.mounted && success) {
      context.go('/login');
      return;
    }
    if (context.mounted) {
      final message = ref.read(authViewModelProvider).errorMessage;
      _showMessage(context, message ?? 'Không thể đăng xuất.');
    }
  }

  void _reloadDashboardForLanguage() {
    final data = ref.read(parentDashboardViewModelProvider).data;
    unawaited(
      ref
          .read(parentDashboardViewModelProvider.notifier)
          .load(
            selectedRosterStudentId: data?.child?.rosterStudentId,
            selectedTourId: data?.trip?.tourId,
          ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _allowsMobileParentMediaUpload(ParentDashboardData data) => true;

  Future<String> _mobileActorRole(WidgetRef ref) async {
    final role = await ref.read(routeGuardsProvider).userRole;
    return role == 'TEACHER' ? 'TEACHER' : 'PARENT';
  }

  Future<String> _mobileActorLabel(WidgetRef ref) async {
    final role = await _mobileActorRole(ref);
    return role == 'TEACHER' ? 'Giáo viên' : 'Phụ huynh';
  }

  void _openMediaTimeline(BuildContext context, ParentDashboardData data) {
    final uri = _mediaTimelineUri(data);
    if (uri == null) {
      _showMessage(context, 'Chưa có tour đang hoạt động để mở ảnh/video.');
      return;
    }
    context.push(uri.toString());
  }

  Future<void> _openIncidentReport(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) async {
    final tourId = _resolveTourId(data);
    if (tourId == null) {
      _showMessage(
        context,
        'Chưa xác định được tour đang hoạt động để báo cáo sự cố.',
      );
      return;
    }
    final reporterRole = await _mobileActorRole(ref);
    if (!context.mounted) return;
    final uri = Uri(
      path: '/incident/create',
      queryParameters: {
        'tourId': tourId,
        'reporterRole': reporterRole,
        if (data.child?.rosterStudentId?.isNotEmpty == true)
          'studentId': data.child!.rosterStudentId!,
      },
    );
    context.push(uri.toString());
  }

  Future<void> _openNewsfeed(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) async {
    final tourId = _resolveTourId(data);
    final actorLabel = await _mobileActorLabel(ref);
    if (!context.mounted) return;
    final queryParameters = <String, String>{'title': 'Bảng tin $actorLabel'};
    queryParameters['actor'] = actorLabel;
    if (tourId != null) {
      queryParameters['tourId'] = tourId;
    }
    final child = data.child;
    final studentId = child?.rosterStudentId?.trim();
    final studentName = child?.name.trim();
    if (studentId != null && studentId.isNotEmpty) {
      queryParameters['studentId'] = studentId;
    }
    if (studentName != null && studentName.isNotEmpty) {
      queryParameters['studentName'] = studentName;
    }
    final uri = Uri(path: '/newsfeed', queryParameters: queryParameters);
    context.push(uri.toString());
  }

  void _openFaceEnroll(BuildContext context, ParentDashboardData data) {
    final child = data.child;
    if (child == null) {
      _showMessage(
        context,
        'Vui lòng liên kết học sinh trước khi đăng ký khuôn mặt.',
      );
      return;
    }
    final studentId = child.rosterStudentId;
    if (studentId == null || studentId.isEmpty) {
      _showMessage(
        context,
        'Chưa có mã học sinh từ hệ thống. Vui lòng liên kết lại.',
      );
      return;
    }
    final operationPlanId = child.operationPlanId ?? data.trip?.tourId;
    if (operationPlanId == null || operationPlanId.isEmpty) {
      _showMessage(
        context,
        'Chưa xác định được tour của học sinh. Vui lòng liên kết lại chuyến đi.',
      );
      return;
    }
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParentFaceEnrollPage(
          studentId: studentId,
          // schoolId omitted – backend resolves from rosterStudentId
          schoolId: '',
          operationPlanId: operationPlanId,
          studentName: child.name,
        ),
      ),
    );
  }

  void _openReplayHistory(
    BuildContext context,
    ParentDashboardData data, {
    String? tourId,
    String? title,
  }) {
    String? id = tourId?.trim();
    if (id == null || id.isEmpty) {
      id = _resolveTourId(data);
    }
    if (id == null || id.isEmpty) {
      for (final history in data.postTourHistory) {
        final historyId = history.tourId.trim();
        if (historyId.isNotEmpty) {
          id = historyId;
          break;
        }
      }
    }
    if (id == null || id.isEmpty) {
      _showMessage(
        context,
        'Chưa có tour để xem lại livestream. Mở lịch sử chuyến đi đã hoàn tất rồi chọn VOD.',
      );
      return;
    }

    String? resolvedTitle = title?.trim();
    if (resolvedTitle == null || resolvedTitle.isEmpty) {
      for (final history in data.postTourHistory) {
        if (history.tourId == id && history.tourName.trim().isNotEmpty) {
          resolvedTitle = history.tourName.trim();
          break;
        }
      }
    }
    resolvedTitle ??=
        data.trip?.tourName ?? data.currentJourney.name;

    context.push(
      '/livestream/replay',
      extra: {
        'tourId': id,
        'title': resolvedTitle,
      },
    );
  }

  Future<void> _openLivestream(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) async {
    final tourId = _resolveTourId(data);
    if (tourId == null) {
      _showMessage(context, 'Chưa có tour đang hoạt động để xem livestream.');
      return;
    }

    try {
      final sessions = await ref
          .read(livestreamRepositoryProvider)
          .getParentActiveLivestreams();
      if (!context.mounted) return;

      final allowed = sessions.where((s) => s.tourId == tourId).toList();
      final selected = await showParentLivestreamPicker(
        context,
        allowed,
        tourIdFilter: tourId,
      );
      if (!context.mounted || selected == null) return;

      context.push(
        '/livestream/watch',
        extra: {
          'tourId': selected.tourId,
          'sessionId': selected.sessionId,
          'title': selected.title ?? selected.tourName,
          'viewerRole': 'PARENT',
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(
        context,
        'Không tải được danh sách livestream. Vui lòng thử lại.',
      );
    }
  }

  void _selectNavigation(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
    int index,
  ) {
    switch (index) {
      case 0:
        return;
      case 1:
        _showChildProfile(context, ref, data);
      case 2:
        _openTracking(context, data);
      case 3:
        context.push('/profile');
    }
  }

  void _openTracking(BuildContext context, ParentDashboardData data) {
    final tourId = _resolveTourId(data);
    if (tourId != null) {
      context.push('/tracking/$tourId');
      return;
    }
    context.push('/tracking');
  }

  Future<void> _openMoreActions(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    final actions = parentMoreQuickActions(data.quickActions);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => ParentMoreActionsPage(
          actions: actions,
          onPressed: (action) {
            Navigator.of(pageContext).pop();
            _openQuickAction(context, ref, data, action);
          },
        ),
      ),
    );
  }

  void _openQuickAction(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
    ParentQuickAction action,
  ) {
    switch (action.kind) {
      case ParentQuickActionKind.linkChild:
        _showLinkChild(context, ref, data);
      case ParentQuickActionKind.childProfile:
        _showChildProfile(context, ref, data);
      case ParentQuickActionKind.documents:
        _showDocuments(context, data);
      case ParentQuickActionKind.authorizations:
        _showAuthorizations(context, ref, data);
      case ParentQuickActionKind.tripInfo:
        context.push('/tours');
      case ParentQuickActionKind.incidents:
        _showIncidents(context, ref, data);
      case ParentQuickActionKind.mediaUpload:
        _showMediaUpload(context, data);
      case ParentQuickActionKind.livestream:
        _openLivestream(context, ref, data);
      case ParentQuickActionKind.postTourHistory:
        context.push('/tours?tab=past');
      case ParentQuickActionKind.media:
        _openMediaTimeline(context, data);
      case ParentQuickActionKind.newsfeed:
        _openNewsfeed(context, ref, data);
      case ParentQuickActionKind.trackingMap:
        _openTracking(context, data);
      case ParentQuickActionKind.aiAssistant:
        context.push('/ai-assistant');
      case ParentQuickActionKind.faceEnroll:
        _openFaceEnroll(context, data);
    }
  }

  Future<void> _showPanel(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLowest,
      builder: (context) {
        final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.86,
              maxChildSize: 0.94,
              minChildSize: 0.45,
              builder: (context, controller) => ListView(
                controller: controller,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconsax.arrow_left),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLinkChild(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    return _showPanel(
      context,
      title: 'Liên kết học sinh',
      child: ParentLinkChildFlow(
        linkedChild: data.child,
        onLinked: () {
          Navigator.of(context).pop();
          ref
              .read(parentDashboardViewModelProvider.notifier)
              .load(selectedRosterStudentId: data.child?.rosterStudentId);
          _showMessage(context, 'Liên kết học sinh thành công.');
        },
      ),
    );
  }

  Future<void> _showChildProfile(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    final child = data.child;
    return _showPanel(
      context,
      title: 'Hồ sơ học sinh',
      child: child == null
          ? _EmptyPanel(
              icon: Iconsax.profile_2user,
              title: 'Chưa liên kết học sinh',
              description:
                  'Hãy liên kết bằng mã định danh học sinh hoặc họ tên kèm ngày sinh đúng roster, sau đó xác thực OTP.',
              actionLabel: 'Liên kết ngay',
              onPressed: () {
                Navigator.of(context).pop();
                _showLinkChild(context, ref, data);
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudentHeader(child: child),
                const SizedBox(height: 12),
                _InfoCard(
                  children: [
                    _InfoRow(label: 'Trường', value: child.schoolName),
                    _InfoRow(label: 'Lớp', value: child.className),
                    _InfoRow(label: 'Mã học sinh', value: child.studentCode),
                    _InfoRow(label: 'Ngày sinh', value: child.dateOfBirth),
                    _InfoRow(label: 'Trạng thái', value: child.statusLabel),
                    _InfoRow(label: 'Liên kết', value: child.linkedAtLabel),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openMediaTimeline(context, data);
                  },
                  icon: const Icon(Iconsax.gallery),
                  label: const Text('Xem ảnh/video của con'),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Ghi chú y tế được phép xem',
                  children: [
                    Text(
                      child.medicalNote,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _showDocuments(BuildContext context, ParentDashboardData data) {
    return _showPanel(
      context,
      title: 'Giấy tờ tham gia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PolicyBanner(
            icon: Iconsax.clipboard_tick,
            text:
                'Phụ huynh chỉ xem trạng thái giấy tờ do nhà trường quản lý. Ghi chú phúc lợi chỉ được gửi khi nhà trường mở quyền.',
          ),
          const SizedBox(height: 12),
          for (final document in data.documents) ...[
            _DocumentTile(document: document),
            const SizedBox(height: 10),
          ],
          if (data.schoolAllowsWelfareNote)
            FilledButton.icon(
              onPressed: () => _showMessage(
                context,
                'Ghi chú phúc lợi đã được lưu ở trạng thái chờ nhà trường rà soát.',
              ),
              icon: const Icon(Iconsax.note_add),
              label: const Text('Gửi ghi chú phúc lợi'),
            )
          else
            const _PolicyBanner(
              icon: Iconsax.lock,
              text: 'Nhà trường chưa mở quyền nhập ghi chú bổ sung.',
            ),
        ],
      ),
    );
  }

  Future<void> _showAuthorizations(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    return _showPanel(
      context,
      title: 'Trạng thái ủy quyền',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PolicyBanner(
            icon: Iconsax.security_safe,
            text:
                'Bạn có thể xác nhận điều khoản chuyến và đồng thuận điểm danh khuôn mặt cho chuyến đi đang hoạt động.',
          ),
          const SizedBox(height: 12),
          if (data.child?.rosterStudentId?.isNotEmpty == true &&
              data.child?.operationPlanId?.isNotEmpty == true)
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => TripConsentPage(
                      rosterStudentId: data.child!.rosterStudentId!,
                      operationPlanId: data.child!.operationPlanId!,
                      studentName: data.child!.name,
                    ),
                  ),
                );
                if (saved == true) {
                  ref
                      .read(parentDashboardViewModelProvider.notifier)
                      .load(
                        selectedRosterStudentId: data.child!.rosterStudentId,
                      );
                }
              },
              icon: const Icon(Iconsax.task_square),
              label: const Text('Xem và xác nhận đồng thuận'),
            ),
          const SizedBox(height: 12),
          if (data.authorizations.isEmpty)
            const _EmptyPanel(
              icon: Iconsax.shield_tick,
              title: 'Chưa có dữ liệu ủy quyền',
              description:
                  'Thông tin ủy quyền sẽ hiển thị khi nhà trường xác nhận hồ sơ.',
            )
          else
            for (final item in data.authorizations) ...[
              _AuthorizationTile(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _showTripInfo(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    final trip = data.trip;
    return _showPanel(
      context,
      title: 'Thông tin chuyến đi',
      child: trip == null
          ? const _EmptyPanel(
              icon: Iconsax.routing_2,
              title: 'Chưa có chuyến đi',
              description:
                  'Thông tin tour sẽ hiển thị khi nhà trường gán học sinh vào tour.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (trip.livestreamActive) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openLivestream(context, ref, data);
                    },
                    icon: const Icon(Iconsax.video_play),
                    label: const Text('Xem livestream đang phát'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openReplayHistory(context, data);
                  },
                  icon: const Icon(Iconsax.video_circle),
                  label: const Text('Xem lại livestream (VOD)'),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: trip.tourName,
                  children: [
                    _InfoRow(label: 'Ngày tour', value: trip.tourDate),
                    _InfoRow(label: 'Phương tiện', value: trip.vehicleLabel),
                    _InfoRow(
                      label: 'Checkpoint hiện tại',
                      value: trip.currentCheckpoint,
                    ),
                    _InfoRow(
                      label: 'Checkpoint tiếp theo',
                      value: trip.nextCheckpoint,
                    ),
                    _InfoRow(
                      label: 'Livestream',
                      value: trip.livestreamActive
                          ? 'Đang phát — bạn được xem'
                          : 'Chưa có phiên đang phát',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Vị trí được phép hiển thị',
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Icon(
                            Iconsax.location,
                            color: AppTheme.secondary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(trip.locationSummary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Lịch trình',
                  children: [
                    for (final item in trip.schedule) _ScheduleRow(item: item),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Ảnh & video',
                  children: [
                    _InfoRow(
                      label: 'Media chuyến đi',
                      value: '${trip.approvedMediaCount} ảnh/video',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Liên hệ tour',
                  children: [
                    for (final contact in trip.contacts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(contact),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _showIncidents(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    return _showPanel(
      context,
      title: 'Sự cố liên quan đến con',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openIncidentReport(context, ref, data);
            },
            icon: const Icon(Iconsax.warning_2),
            label: const Text('Báo cáo sự cố'),
          ),
          const SizedBox(height: 12),
          if (data.incidents.isEmpty)
            const _EmptyPanel(
              icon: Iconsax.verify,
              title: 'Không có sự cố',
              description:
                  'Nếu có sự cố được phép hiển thị, thông tin sẽ xuất hiện tại đây.',
            )
          else
            for (final incident in data.incidents) ...[
              _IncidentTile(incident: incident),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _showMediaUpload(
    BuildContext context,
    ParentDashboardData data,
  ) {
    final mediaAllowed = _allowsMobileParentMediaUpload(data);
    return _showPanel(
      context,
      title: 'Gửi ảnh/video tour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!mediaAllowed)
            const _PolicyBanner(
              icon: Iconsax.close_circle,
              text:
                  'Chỉ phụ huynh đi cùng và có ủy quyền media mới được gửi ảnh/video.',
            )
          else ...[
            const _PolicyBanner(
              icon: Iconsax.camera,
              text:
                  'Media gửi lên sẽ hiển thị ngay cho mọi người trong chuyến đi.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final uri = _mediaTimelineUri(data);
                if (uri == null) {
                  _showMessage(
                    context,
                    'Chưa có tour đang hoạt động để gửi media.',
                  );
                  return;
                }
                Navigator.of(context).pop();
                context.push(uri.toString());
              },
              icon: const Icon(Iconsax.document_upload),
              label: const Text('Chọn ảnh/video'),
            ),
          ],
          const SizedBox(height: 16),
          if (data.mediaSubmissions.isNotEmpty) ...[
            _SectionTitle(title: 'Lần gửi gần đây'),
            const SizedBox(height: 8),
            for (final submission in data.mediaSubmissions) ...[
              _MediaSubmissionTile(submission: submission),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showPostTourHistory(
    BuildContext context,
    ParentDashboardData data,
  ) {
    final tourId = _resolveTourId(data);
    return _showPanel(
      context,
      title: 'Lịch sử sau tour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tourId != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openReplayHistory(context, data);
              },
              icon: const Icon(Iconsax.video_circle),
              label: const Text('Xem lại livestream (VOD)'),
            ),
            const SizedBox(height: 12),
          ],
          if (data.postTourHistory.isEmpty)
            const _EmptyPanel(
              icon: Iconsax.clock,
              title: 'Chưa có lịch sử',
              description:
                  'Lịch sử tour đã đóng sẽ hiển thị trong thời hạn lưu trữ.',
            )
          else ...[
            const _PolicyBanner(
              icon: Iconsax.timer_1,
              text:
                  'Sau khi tour đóng, dữ liệu realtime và livestream live không khả dụng; chỉ còn lịch sử trong thời hạn lưu trữ. Bạn có thể gửi đánh giá chuyến đi.',
            ),
            if (data.postTourHistory.any(
              (h) => h.showMediaRetentionBanner,
            )) ...[
              const SizedBox(height: 12),
              _PolicyBanner(
                icon: Iconsax.warning_2,
                text: () {
                  final nearest =
                      [
                        ...data.postTourHistory,
                      ].where((h) => h.showMediaRetentionBanner).toList()..sort(
                        (a, b) => (a.mediaRetentionDaysRemaining ?? 99)
                            .compareTo(b.mediaRetentionDaysRemaining ?? 99),
                      );
                  final days = nearest.first.mediaRetentionDaysRemaining ?? 0;
                  return 'Ảnh tour còn $days ngày trước khi xóa. Hãy xem và lưu lại những khoảnh khắc quan trọng.';
                }(),
              ),
            ],
            const SizedBox(height: 12),
            for (final history in data.postTourHistory) ...[
              _HistoryTile(
                history: history,
                onOpen: history.tourId.isNotEmpty &&
                        data.child?.rosterStudentId?.isNotEmpty == true
                    ? () {
                        Navigator.of(context).pop();
                        final uri = Uri(
                          path: '/parent/tour-history',
                          queryParameters: {
                            'tourId': history.tourId,
                            'child': data.child!.rosterStudentId!,
                            if (data.child!.name.trim().isNotEmpty)
                              'childName': data.child!.name,
                          },
                        );
                        context.push(uri.toString());
                      }
                    : null,
                onReplay: history.tourId.trim().isNotEmpty
                    ? () {
                        Navigator.of(context).pop();
                        _openReplayHistory(
                          context,
                          data,
                          tourId: history.tourId,
                          title: history.tourName,
                        );
                      }
                    : null,
                onFeedback: history.canSubmitFeedback &&
                        history.tourId.isNotEmpty
                    ? () {
                        Navigator.of(context).pop();
                        final uri = Uri(
                          path: '/parent/feedback',
                          queryParameters: {
                            'tourId': history.tourId,
                            if (history.tourName.trim().isNotEmpty)
                              'tourName': history.tourName,
                          },
                        );
                        context.push(uri.toString());
                      }
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(parentDashboardViewModelProvider);
    final data = viewState.data;
    if (data != null) {
      return _buildDashboard(context, ref, data);
    }
    if (viewState.isLoading) {
      // Keep brand splash from remounting — solid hold matches splash sky.
      return const AppBootstrapHold();
    }
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:           ParentEmptyState(
            icon: Iconsax.cloud_remove,
            title: 'Không tải được bảng điều khiển',
            description:
                viewState.errorMessage ?? 'Vui lòng kiểm tra mạng và thử lại.',
            actionLabel: 'Thử lại',
            onAction: () =>
                ref.read(parentDashboardViewModelProvider.notifier).load(),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    ParentDashboardData data,
  ) {
    final unreadNotifications =
        ref.watch(notificationRealtimeProvider).unreadCount;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      drawer: _ParentDrawer(
        onHome: () => Navigator.of(context).pop(),
        onOpen: (kind) {
          Navigator.of(context).pop();
          _openQuickAction(
            context,
            ref,
            data,
            ParentQuickAction(kind: kind, label: ''),
          );
        },
        onLogout: () => _logout(context, ref),
      ),
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        backgroundColor: AppTheme.surface,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Mở trình đơn',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Iconsax.menu_1),
          ),
        ),
        title: Text(
          'Điều khiển PH',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: LanguageSwitcher(onChanged: _reloadDashboardForLanguage),
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            key: const Key('parent-dashboard-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _DashboardHeader(updatedLabel: data.updatedLabel),
              const SizedBox(height: 16),
              if (data.trip == null)
                const _NoActiveTourCard()
              else
                _JourneyCard(
                  journey: data.currentJourney,
                  livestreamActive: data.trip?.livestreamActive == true,
                  onTap: null,
                  onWatchLive: () => _openLivestream(context, ref, data),
                  onWatchVod: () => _openReplayHistory(context, data),
                ),
              if (data.pendingTripLinks.isNotEmpty ||
                  data.children.isEmpty) ...[
                const SizedBox(height: 24),
                _PendingTripLinkSection(
                  activities: data.pendingTripLinks,
                  linkedChildrenCount: data.children.length,
                  onLink: () => _showLinkChild(context, ref, data),
                ),
              ],
              const SizedBox(height: 24),
              _QuickAccessSection(
                actions: parentPinnedQuickActions(data.quickActions),
                onPressed: (action) =>
                    _openQuickAction(context, ref, data, action),
                onSeeMore: () => _openMoreActions(context, ref, data),
              ),
              const SizedBox(height: 24),
              _ChildProfileSummary(
                child: data.child,
                children: data.children,
                onSelectChild: (rosterStudentId) => ref
                    .read(parentDashboardViewModelProvider.notifier)
                    .selectChild(rosterStudentId),
                onTap: () => _showChildProfile(context, ref, data),
                onLink: () => _showLinkChild(context, ref, data),
                onViewMedia: () => _openMediaTimeline(context, data),
              ),
              if (data.authorizations.isNotEmpty) ...[
                const SizedBox(height: 24),
                _AuthorizationPreview(
                  items: data.authorizations,
                  onTap: () => _showAuthorizations(context, ref, data),
                ),
              ],
              if (data.recentAlerts.isNotEmpty) ...[
                const SizedBox(height: 24),
                _RecentAlertsSection(
                  alerts: data.recentAlerts,
                  onViewAll: () => context.push('/notifications'),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ParentBottomNav(
        selectedIndex: 0,
        onDestinationSelected: (index) =>
            _selectNavigation(context, ref, data, index),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.updatedLabel});

  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    return ParentSectionHeader(
      title: 'Bảng điều khiển phụ huynh',
      subtitle: updatedLabel,
      trailing: const ParentIconWell(
        icon: Iconsax.refresh_2,
        size: 40,
        iconSize: 20,
      ),
    );
  }
}

class _NoActiveTourCard extends StatelessWidget {
  const _NoActiveTourCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DashboardCard(
      emphasized: true,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(
                Iconsax.routing_2,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không có tour nào đang diễn ra',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tour hiện tại sẽ tự động hiển thị khi hệ thống có dữ liệu đang hoạt động.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTripLinkSection extends StatelessWidget {
  const _PendingTripLinkSection({
    required this.activities,
    required this.linkedChildrenCount,
    required this.onLink,
  });

  final List<ParentPendingTripLink> activities;
  final int linkedChildrenCount;
  final VoidCallback onLink;

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    // Match web: hide empty section when parent already has linked children.
    if (activities.isEmpty && linkedChildrenCount > 0) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParentSectionHeader(
          title: 'Hoạt động chờ liên kết học sinh',
          subtitle: activities.isEmpty
              ? 'Chưa có hoạt động trải nghiệm nào chờ liên kết theo số điện thoại trong hồ sơ phụ huynh.'
              : 'Roster khớp SĐT tài khoản của bạn. Chọn hoạt động để liên kết đúng học sinh.',
          trailing: activities.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: AppTheme.cta.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${activities.length} chờ',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.cta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          _DashboardCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.info_circle,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Khi nhà trường có roster khớp SĐT của bạn, hoạt động sẽ hiện tại đây.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < activities.length; i++) ...[
            _PendingTripLinkCard(
              activity: activities[i],
              dateLabel: _formatDate(activities[i].tourDate),
              onLink: onLink,
            ),
            if (i < activities.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PendingTripLinkCard extends StatelessWidget {
  const _PendingTripLinkCard({
    required this.activity,
    required this.dateLabel,
    required this.onLink,
  });

  final ParentPendingTripLink activity;
  final String dateLabel;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DashboardCard(
      emphasized: true,
      primaryBorder: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    activity.displayTourName,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: AppTheme.cta.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Chờ liên kết',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.cta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PendingMetaRow(
              icon: Iconsax.building,
              label: activity.schoolName?.trim().isNotEmpty == true
                  ? activity.schoolName!.trim()
                  : 'Trường',
            ),
            const SizedBox(height: 6),
            _PendingMetaRow(icon: Iconsax.calendar_1, label: dateLabel),
            const SizedBox(height: 6),
            _PendingMetaRow(
              icon: Iconsax.mobile,
              label: activity.parentPhoneMasked?.trim().isNotEmpty == true
                  ? activity.parentPhoneMasked!.trim()
                  : 'SĐT trong roster',
            ),
            if (activity.pendingStudentCount > 0) ...[
              const SizedBox(height: 6),
              _PendingMetaRow(
                icon: Iconsax.people,
                label: '${activity.pendingStudentCount} học sinh chờ liên kết',
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onLink,
              icon: const Icon(Iconsax.link_2, size: 18),
              label: const Text('Liên kết học sinh'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingMetaRow extends StatelessWidget {
  const _PendingMetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.journey,
    required this.livestreamActive,
    required this.onTap,
    required this.onWatchLive,
    required this.onWatchVod,
  });

  final ParentJourneySummary journey;
  final bool livestreamActive;
  final VoidCallback? onTap;
  final VoidCallback onWatchLive;
  final VoidCallback onWatchVod;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DashboardCard(
      emphasized: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HÀNH TRÌNH ĐANG DIỄN RA',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          journey.name,
                          style: textTheme.titleLarge?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (livestreamActive)
                    const _StatusChip(
                      label: 'LIVE',
                      color: AppTheme.accentRed,
                      icon: Iconsax.record_circle,
                    )
                  else
                    _StatusChip(
                      label: journey.statusLabel,
                      color: AppTheme.accentGreen,
                      icon: Iconsax.tick_circle,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Còn lại',
                            value: journey.remainingDistance,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppTheme.surfaceVariant),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Iconsax.tick_circle,
                          size: 22,
                          color: AppTheme.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            journey.punctualityLabel,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Iconsax.arrow_right_3,
                          color: AppTheme.neutral500,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (livestreamActive) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onWatchLive,
                        icon: const Icon(Iconsax.video_play, size: 18),
                        label: const Text('Xem Live'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onWatchVod,
                      icon: const Icon(Iconsax.video_circle, size: 18),
                      label: const Text('Xem VOD'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection({
    required this.actions,
    required this.onPressed,
    required this.onSeeMore,
  });

  final List<ParentQuickAction> actions;
  final ValueChanged<ParentQuickAction> onPressed;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParentSectionHeader(
          title: 'Truy cập nhanh',
          subtitle: 'Các thao tác dùng nhiều nhất trong chuyến đi.',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < actions.length; i++) ...[
          _QuickAccessTile(
            action: actions[i],
            onPressed: () => onPressed(actions[i]),
          ),
          if (i < actions.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: onSeeMore,
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
                    child: const Icon(
                      Iconsax.element_plus,
                      color: AppTheme.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thêm thao tác',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Giấy tờ, ủy quyền, livestream, trợ lý AI…',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Iconsax.arrow_right_3,
                    color: AppTheme.neutral500,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.action,
    required this.onPressed,
  });

  final ParentQuickAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = parentQuickActionAccent(action.kind);
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.neutral200),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    parentQuickActionIcon(action.kind),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parentQuickActionSubtitle(action.kind),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color: AppTheme.neutral500,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentBottomNav extends StatelessWidget {
  const _ParentBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _items = <({IconData icon, IconData selected, String label})>[
    (
      icon: Iconsax.home,
      selected: Iconsax.home_2,
      label: 'Trang chủ',
    ),
    (
      icon: Iconsax.profile_2user,
      selected: Iconsax.profile_2user,
      label: 'Con',
    ),
    (
      icon: Iconsax.location,
      selected: Iconsax.location_tick,
      label: 'Theo dõi',
    ),
    (
      icon: Iconsax.user,
      selected: Iconsax.profile_circle,
      label: 'Hồ sơ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      elevation: 8,
      shadowColor: AppTheme.ink.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.neutral200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _ParentBottomNavItem(
                    item: _items[i],
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentBottomNavItem extends StatelessWidget {
  const _ParentBottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selected, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: AppTheme.motionNormal,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.selected : item.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildProfileSummary extends StatelessWidget {
  const _ChildProfileSummary({
    required this.child,
    required this.children,
    required this.onSelectChild,
    required this.onTap,
    required this.onLink,
    required this.onViewMedia,
  });

  final ParentChildSummary? child;
  final List<ParentChildSummary> children;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onTap;
  final VoidCallback onLink;
  final VoidCallback onViewMedia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: children.length > 1
              ? 'Học sinh đã liên kết (${children.length})'
              : 'Hồ sơ của con',
        ),
        if (children.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = children[index];
                final selected = child?.rosterStudentId == item.rosterStudentId;
                return ChoiceChip(
                  label: Text(item.name),
                  selected: selected,
                  onSelected: (_) {
                    final rosterStudentId = item.rosterStudentId;
                    if (rosterStudentId != null && rosterStudentId.isNotEmpty) {
                      onSelectChild(rosterStudentId);
                    }
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        _DashboardCard(
          primaryBorder: true,
          child: child == null
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const _ChildAvatar(),
                      const SizedBox(height: 12),
                      const Text(
                        'Chưa có học sinh nào',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Liên kết hồ sơ học sinh để xem tour, điểm danh và thông báo liên quan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onLink,
                        icon: const Icon(Iconsax.link_2),
                        label: const Text('Liên kết ngay'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: onTap,
                          leading: const _ChildAvatar(),
                          title: Text(
                            child!.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${child!.className} - ${child!.schoolName}',
                          ),
                          trailing: const Icon(
                            Iconsax.arrow_right_3,
                            color: AppTheme.neutral500,
                            size: 18,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: onViewMedia,
                          icon: const Icon(Iconsax.gallery),
                          label: const Text('Xem ảnh/video của con'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _AuthorizationPreview extends StatelessWidget {
  const _AuthorizationPreview({required this.items, required this.onTap});

  final List<ParentAuthorizationSummary> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle(title: 'Ủy quyền và truy cập')),
            TextButton(onPressed: onTap, child: const Text('Chi tiết')),
          ],
        ),
        const SizedBox(height: 8),
        _DashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  _StatusChip(
                    label: item.statusLabel,
                    color: _authorizationColor(item.status),
                    icon: _authorizationIcon(item.kind),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentAlertsSection extends StatelessWidget {
  const _RecentAlertsSection({required this.alerts, required this.onViewAll});

  final List<ParentAlert> alerts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle(title: 'Cảnh báo gần đây')),
            TextButton(onPressed: onViewAll, child: const Text('Xem tất cả')),
          ],
        ),
        const SizedBox(height: 8),
        for (final alert in alerts.take(3)) ...[
          _AlertCard(alert: alert),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ParentAlert alert;

  IconData get _icon => switch (alert.kind) {
    ParentAlertKind.confirmed => Iconsax.tick_circle,
    ParentAlertKind.warning => Iconsax.warning_2,
    ParentAlertKind.location => Iconsax.location,
  };

  Color get _color => switch (alert.kind) {
    ParentAlertKind.confirmed => AppTheme.accentGreen,
    ParentAlertKind.warning => AppTheme.accentOrange,
    ParentAlertKind.location => AppTheme.secondary,
  };

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _color.withValues(alpha: 0.14),
            child: Icon(_icon, color: _color),
          ),
          title: Text(
            alert.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(alert.timeLabel),
        ),
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.child});

  final ParentChildSummary child;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      primaryBorder: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ChildAvatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('${child.className} - ${child.schoolName}'),
                  const SizedBox(height: 6),
                  _StatusChip(
                    label: child.statusLabel,
                    color: AppTheme.accentGreen,
                    icon: Iconsax.tick_circle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final ParentDocumentStatus document;

  @override
  Widget build(BuildContext context) {
    final color = switch (document.status) {
      ParentDocumentStatusKind.ready => AppTheme.accentGreen,
      ParentDocumentStatusKind.pending => AppTheme.accentOrange,
      ParentDocumentStatusKind.missing => AppTheme.accentRed,
    };
    return _InfoCard(
      title: document.title,
      children: [
        _StatusChip(
          label: document.statusLabel,
          color: color,
          icon: Iconsax.clipboard_tick,
        ),
        const SizedBox(height: 10),
        Text(document.note),
        const SizedBox(height: 8),
        _InfoRow(label: 'Người rà soát', value: document.reviewerLabel),
      ],
    );
  }
}

class _AuthorizationTile extends StatelessWidget {
  const _AuthorizationTile({required this.item});

  final ParentAuthorizationSummary item;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: item.title,
      children: [
        _StatusChip(
          label: item.statusLabel,
          color: _authorizationColor(item.status),
          icon: _authorizationIcon(item.kind),
        ),
        const SizedBox(height: 10),
        Text(item.detail),
        const SizedBox(height: 8),
        _InfoRow(label: 'Xác nhận bởi', value: item.updatedByLabel),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});

  final ParentScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      ParentScheduleStatus.completed => AppTheme.accentGreen,
      ParentScheduleStatus.current => AppTheme.secondary,
      ParentScheduleStatus.upcoming => AppTheme.onSurfaceVariant,
    };
    final icon = switch (item.status) {
      ParentScheduleStatus.completed => Iconsax.tick_circle,
      ParentScheduleStatus.current => Iconsax.record_circle,
      ParentScheduleStatus.upcoming => Iconsax.record,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              item.time,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(item.title)),
        ],
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident});

  final ParentIncidentReport incident;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: incident.type,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: incident.severityLabel,
              color: AppTheme.accentOrange,
              icon: Iconsax.danger,
            ),
            _StatusChip(
              label: incident.statusLabel,
              color: AppTheme.accentGreen,
              icon: Iconsax.tick_square,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoRow(label: 'Thời gian', value: incident.timeLabel),
        _InfoRow(label: 'Vị trí', value: incident.locationLabel),
        const SizedBox(height: 8),
        Text(incident.summary),
        const SizedBox(height: 8),
        Text(
          incident.staffNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MediaSubmissionTile extends StatelessWidget {
  const _MediaSubmissionTile({required this.submission});

  final ParentMediaSubmission submission;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: submission.activityLabel,
      children: [
        _InfoRow(label: 'Gửi lúc', value: submission.uploadedAtLabel),
        _InfoRow(label: 'Trạng thái', value: submission.statusLabel),
        Text(submission.moderationNote),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.history,
    this.onOpen,
    this.onReplay,
    this.onFeedback,
  });

  final ParentPostTourHistory history;
  final VoidCallback? onOpen;
  final VoidCallback? onReplay;
  final VoidCallback? onFeedback;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: history.tourName,
      children: [
        _InfoRow(label: 'Ngày', value: history.dateLabel),
        _InfoRow(label: 'Lưu trữ', value: history.retentionLabel),
        _InfoRow(label: 'Điểm danh', value: history.attendanceSummary),
        _InfoRow(label: 'Sự cố', value: history.incidentSummary),
        _InfoRow(label: 'Ảnh & video', value: history.mediaSummary),
        if (onOpen != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Iconsax.gallery, size: 18),
            label: const Text('Xem chi tiết & media'),
          ),
        ],
        if (onReplay != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReplay,
            icon: const Icon(Iconsax.video_play, size: 18),
            label: const Text('Xem lại livestream (VOD)'),
          ),
        ],
        if (onFeedback != null) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onFeedback,
            icon: const Icon(Iconsax.star_1, size: 18),
            label: const Text('Đánh giá chuyến đi'),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.emphasized = false,
    this.primaryBorder = false,
  });

  final Widget child;
  final bool emphasized;
  final bool primaryBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: primaryBorder || emphasized
              ? AppTheme.primary.withValues(alpha: 0.28)
              : AppTheme.surfaceVariant,
          width: emphasized || primaryBorder ? 2 : 1,
        ),
        boxShadow: emphasized ? AppTheme.shadowMd : AppTheme.shadowSm,
      ),
      child: child,
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: AppTheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Iconsax.profile_2user,
        size: 30,
        color: AppTheme.secondary,
      ),
    );
  }
}

class _ParentDrawer extends StatelessWidget {
  const _ParentDrawer({
    required this.onHome,
    required this.onOpen,
    required this.onLogout,
  });

  final VoidCallback onHome;
  final ValueChanged<ParentQuickActionKind> onOpen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final drawerWidth = width.clamp(280.0, 320.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerBrandHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  _DrawerSectionLabel(label: 'Chính'),
                  _DrawerNavTile(
                    icon: Iconsax.home_2,
                    label: 'Trang chủ',
                    selected: true,
                    onTap: onHome,
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.notification,
                    label: 'Thông báo',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/notifications');
                    },
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.profile_circle,
                    label: 'Hồ sơ tài khoản',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/profile');
                    },
                  ),
                  const SizedBox(height: 8),
                  _DrawerSectionLabel(label: 'Con & chuyến đi'),
                  _DrawerNavTile(
                    icon: Iconsax.link_2,
                    label: 'Liên kết con',
                    onTap: () => onOpen(ParentQuickActionKind.linkChild),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.profile_2user,
                    label: 'Hồ sơ con',
                    onTap: () => onOpen(ParentQuickActionKind.childProfile),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.map,
                    label: 'Chuyến đi',
                    onTap: () => onOpen(ParentQuickActionKind.tripInfo),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.shield_tick,
                    label: 'Ủy quyền dữ liệu',
                    onTap: () => onOpen(ParentQuickActionKind.authorizations),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.scan,
                    label: 'Đăng ký khuôn mặt',
                    onTap: () => onOpen(ParentQuickActionKind.faceEnroll),
                  ),
                  const SizedBox(height: 8),
                  _DrawerSectionLabel(label: 'An toàn & media'),
                  _DrawerNavTile(
                    icon: Iconsax.video_play,
                    label: 'Livestream',
                    onTap: () => onOpen(ParentQuickActionKind.livestream),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.location,
                    label: 'Theo dõi hành trình',
                    onTap: () => onOpen(ParentQuickActionKind.trackingMap),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.gallery,
                    label: 'Ảnh & video',
                    onTap: () => onOpen(ParentQuickActionKind.media),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.activity,
                    label: 'Bảng tin',
                    onTap: () => onOpen(ParentQuickActionKind.newsfeed),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.warning_2,
                    label: 'Báo cáo sự cố',
                    onTap: () => onOpen(ParentQuickActionKind.incidents),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.clock,
                    label: 'Lịch sử sau tour',
                    onTap: () => onOpen(ParentQuickActionKind.postTourHistory),
                  ),
                  _DrawerNavTile(
                    icon: Iconsax.message_question,
                    label: 'Trợ lý AI',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/ai-assistant');
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppTheme.neutral200),
                  const SizedBox(height: 8),
                  const ParentBanner(
                    icon: Iconsax.shield_tick,
                    text:
                        'Dữ liệu vị trí và media của con được bảo vệ theo ủy quyền của bạn.',
                    tone: ParentBannerTone.info,
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: const SizedBox(
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              ParentIconWell(
                                icon: Iconsax.logout_1,
                                size: 36,
                                iconSize: 18,
                                backgroundColor: Color(0xFFFECACA),
                                iconColor: AppTheme.accentRed,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    color: AppTheme.accentRed,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerBrandHeader extends StatelessWidget {
  const _DrawerBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Iconsax.shield_tick,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VentourKid',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Khu vực phụ huynh',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  ParentIconWell(
                    icon: icon,
                    size: 36,
                    iconSize: 18,
                    backgroundColor: selected
                        ? Colors.white
                        : AppTheme.primarySoft,
                    iconColor: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? AppTheme.primary : AppTheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Iconsax.tick_circle,
                      size: 18,
                      color: AppTheme.primary,
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

Color _authorizationColor(ParentAuthorizationStatus status) {
  return switch (status) {
    ParentAuthorizationStatus.authorized => AppTheme.accentGreen,
    ParentAuthorizationStatus.notAuthorized => AppTheme.accentRed,
    ParentAuthorizationStatus.pending => AppTheme.accentOrange,
    ParentAuthorizationStatus.notApplicable => AppTheme.onSurfaceVariant,
  };
}

IconData _authorizationIcon(ParentAuthorizationKind kind) {
  return switch (kind) {
    ParentAuthorizationKind.face => Iconsax.scan,
    ParentAuthorizationKind.media => Iconsax.gallery,
    ParentAuthorizationKind.livestream => Iconsax.video_play,
    ParentAuthorizationKind.tracker => Iconsax.gps,
  };
}
