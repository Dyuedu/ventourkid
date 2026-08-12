import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../attendance/domain/entities/offline_attendance.dart';
import '../utils/guide_itinerary_tree.dart';

bool _checkpointIsActive(GuideTourItineraryCheckpoint checkpoint) =>
    checkpoint.isCurrent || checkpoint.isArrived;

String? _checkpointStatusLabel(GuideTourItineraryCheckpoint checkpoint) {
  if (checkpoint.isCompleted) return 'Đã xong';
  if (checkpoint.isArrived) return 'Xe đã đến';
  if (checkpoint.isCurrent) return 'Đang ở đây';
  return null;
}

Color _checkpointAccentColor(GuideTourItineraryCheckpoint checkpoint) {
  if (checkpoint.isCompleted) return AppTheme.accentGreen;
  if (checkpoint.isArrived) return AppTheme.accentOrange;
  if (checkpoint.isCurrent) return AppTheme.secondary;
  return AppTheme.neutral200;
}

class GuideItineraryPage extends ConsumerStatefulWidget {
  const GuideItineraryPage({
    super.key,
    required this.tourId,
    this.prepReadOnlyHint = false,
  });

  final String tourId;

  /// From dashboard upcoming tab (`prep=1`) — still re-checked against tour meta.
  final bool prepReadOnlyHint;

  @override
  ConsumerState<GuideItineraryPage> createState() => _GuideItineraryPageState();
}

class _GuideItineraryPageState extends ConsumerState<GuideItineraryPage> {
  GuideTourItinerary? _itinerary;
  bool _loading = true;
  bool _completingCheckpoint = false;
  bool _isTeacher = false;
  bool _operationsLocked = false;
  String? _openingPlanItemId;
  String? _error;
  _ItineraryFeedback? _feedback;

  static const _prepLockedMessage =
      'Tour chưa tới ngày đi, chỉ xem kế hoạch.';

  @override
  void initState() {
    super.initState();
    _operationsLocked = widget.prepReadOnlyHint;
    Future.microtask(() async {
      final role = await ref.read(routeGuardsProvider).userRole;
      if (mounted) {
        setState(() => _isTeacher = role == 'TEACHER');
      }
      await _loadItinerary();
    });
  }

  void _showPrepLockedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_prepLockedMessage)));
  }

  bool _inferPrepFromItinerary(GuideTourItinerary itinerary) {
    DateTime? earliest;
    void consider(DateTime? value) {
      if (value == null) return;
      final local = value.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (earliest == null || day.isBefore(earliest!)) {
        earliest = day;
      }
    }

    for (final checkpoint in itinerary.checkpoints) {
      consider(checkpoint.plannedStart);
    }
    for (final item in itinerary.items) {
      consider(item.plannedStart);
      consider(item.plannedEnd);
    }
    if (earliest == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return earliest!.isAfter(today);
  }

  Future<AttendanceTour?> _resolveTourMeta() async {
    final repo = ref.read(offlineAttendanceRepositoryProvider);
    try {
      final upcoming = await repo.listUpcomingTours(days: 30);
      for (final tour in upcoming) {
        if (tour.tourId == widget.tourId) return tour;
      }
    } on Object {
      // Fall through to cached active tours.
    }
    try {
      final active = await repo.getCachedTours();
      for (final tour in active) {
        if (tour.tourId == widget.tourId) return tour;
      }
    } on Object {
      // Ignore — itinerary view can still load without meta.
    }
    return null;
  }

  bool _computeOperationsLocked({
    required AttendanceTour? meta,
    required GuideTourItinerary itinerary,
  }) {
    if (widget.prepReadOnlyHint) return true;
    if (meta != null) return meta.isUpcomingPrepOnly;
    return _inferPrepFromItinerary(itinerary);
  }

  void _showFeedback({
    required String title,
    required String message,
    required bool isError,
  }) {
    setState(() {
      _feedback = _ItineraryFeedback(
        title: title,
        message: message,
        isError: isError,
      );
    });
  }

  void _clearFeedback() {
    if (_feedback == null) return;
    setState(() => _feedback = null);
  }

  String? _apiErrorCode(ApiException? error) {
    final details = error?.details;
    if (details is Map) {
      return details['code']?.toString();
    }
    return null;
  }

  Future<void> _loadItinerary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(offlineAttendanceRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.getTourItinerary(widget.tourId),
        _resolveTourMeta(),
      ]);
      if (!mounted) return;
      final itinerary = results[0]! as GuideTourItinerary;
      final meta = results[1] as AttendanceTour?;
      setState(() {
        _itinerary = itinerary;
        _operationsLocked = _computeOperationsLocked(
          meta: meta,
          itinerary: itinerary,
        );
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final apiError = ApiException.maybeFrom(error);
      setState(() {
        _loading = false;
        _error =
            apiError?.message ??
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _completeCurrentCheckpoint(GuideTourItinerary itinerary) async {
    if (_operationsLocked) {
      _showPrepLockedSnack();
      return;
    }
    final checkpointId = itinerary.currentCheckpointId;
    final vehicleId = _resolveGuideVehicle(itinerary);
    if (checkpointId == null || checkpointId.isEmpty || vehicleId.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_completingCheckpoint,
      builder: (context) => _CompleteCheckpointDialog(
        currentName: itinerary.currentCheckpointName ?? 'Mốc hiện tại',
        nextName: itinerary.nextCheckpointName,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _completingCheckpoint = true;
      _feedback = null;
    });
    try {
      final result = await ref
          .read(offlineAttendanceRepositoryProvider)
          .completeCheckpoint(
            tourId: widget.tourId,
            operationVehicleId: vehicleId,
            checkpointId: checkpointId,
          );
      if (!mounted) return;
      final nextName = itinerary.nextCheckpointName;
      final promptClosing =
          result['promptTourClosing'] == true ||
          (result['completedCheckpointKind']?.toString().toUpperCase() ==
              'DROPOFF');
      _showFeedback(
        title: nextName != null ? 'Đã chuyển mốc' : 'Hoàn thành lịch trình',
        message: nextName != null
            ? 'Tiếp theo: $nextName'
            : 'Bạn đã hoàn thành toàn bộ mốc trên tuyến.',
        isError: false,
      );
      await _loadItinerary();
      if (!mounted) return;
      if (promptClosing) {
        final goClosing = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Đóng tour'),
            content: const Text(
              'Đã trả HS tại trường. Sang checklist đóng tour?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sang đóng tour'),
              ),
            ],
          ),
        );
        if (goClosing == true && mounted) {
          await context.push('/closing?tourId=${widget.tourId}');
        }
      }
    } on Object catch (error) {
      if (!mounted) return;
      final apiError = ApiException.maybeFrom(error);
      final code = _apiErrorCode(apiError);
      final rawMessage =
          apiError?.message ?? error.toString().replaceFirst('Exception: ', '');
      if (code == 'CP_ATTENDANCE_REQUIRED' ||
          rawMessage.toLowerCase().contains('điểm danh')) {
        _showFeedback(
          title: 'Chưa thể hoàn thành mốc',
          message: rawMessage.contains('điểm danh')
              ? rawMessage
              : 'Chưa hoàn thành điểm danh bắt buộc tại mốc này. '
                    'Hãy điểm danh xong rồi thử lại.',
          isError: true,
        );
      } else {
        _showFeedback(
          title: 'Không hoàn thành được mốc',
          message: rawMessage,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _completingCheckpoint = false);
      }
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('HH:mm').format(value.toLocal());
  }

  String _formatWindow(GuideTourItineraryItem item) {
    final start = _formatTime(item.plannedStart);
    final end = _formatTime(item.plannedEnd);
    if (start == '—' && end == '—') return 'Chưa có giờ kế hoạch';
    if (end == '—') return start;
    return '$start - $end';
  }

  /// Prefer the guide's assigned vehicle. Plan-item vehicle is used only when
  /// it belongs to this guide — otherwise API returns ATT_VEHICLE_FORBIDDEN.
  String _resolveGuideVehicle(GuideTourItinerary itinerary) {
    if (itinerary.operationVehicleId?.isNotEmpty == true) {
      return itinerary.operationVehicleId!;
    }
    if (itinerary.myVehicleIds.isNotEmpty) {
      return itinerary.myVehicleIds.first;
    }
    if (itinerary.vehicles.isNotEmpty) {
      return itinerary.vehicles.first.id;
    }
    return '';
  }

  String _resolveAttendanceVehicle(
    GuideTourItinerary itinerary,
    GuideTourItineraryItem item,
  ) {
    final itemVehicleId = item.operationVehicleId;
    final mine = itinerary.myVehicleIds;
    if (itemVehicleId != null &&
        itemVehicleId.isNotEmpty &&
        (mine.isEmpty || mine.contains(itemVehicleId))) {
      return itemVehicleId;
    }
    return _resolveGuideVehicle(itinerary);
  }

  Future<void> _startItineraryItem(
    GuideTourItinerary itinerary,
    GuideTourItineraryItem item,
  ) async {
    if (_operationsLocked) {
      _showPrepLockedSnack();
      return;
    }
    if (_openingPlanItemId != null) return;
    setState(() => _openingPlanItemId = item.planItemId);
    try {
      final isLivestream = item.itemKind.toUpperCase() == 'LIVESTREAM';
      final anchorId = item.checkpointId;
      if (anchorId != null && anchorId.isNotEmpty) {
        if (itinerary.isCheckpointCompleted(anchorId)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Mốc này đã hoàn thành — không mở lại điểm danh/livestream.',
                ),
              ),
            );
          }
          return;
        }
        if (!itinerary.isCheckpointOperable(anchorId)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  itinerary.currentCheckpointName == null ||
                          itinerary.currentCheckpointName!.isEmpty
                      ? 'Chỉ thao tác mốc hiện tại'
                      : 'Chỉ thao tác mốc hiện tại: ${itinerary.currentCheckpointName}',
                ),
              ),
            );
          }
          return;
        }
      }
      if (item.itemKind.toUpperCase() == 'VEHICLE_INSPECTION') {
        if (!_isTeacher) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Mốc kiểm tra xe do giáo viên xác nhận — HDV chỉ theo dõi trạng thái.',
                ),
              ),
            );
          }
          return;
        }
        if (item.completed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mốc kiểm tra xe đã được xác nhận.'),
              ),
            );
          }
          return;
        }
        final vehicleId = _resolveAttendanceVehicle(itinerary, item);
        final confirmed = await context.push<bool>(
          Uri(
            path: '/teacher/vehicle-inspection',
            queryParameters: {
              'tourId': widget.tourId,
              'planItemId': item.planItemId,
              if (vehicleId.isNotEmpty) 'vehicleId': vehicleId,
              if ((item.vehicleLabel ?? '').isNotEmpty)
                'vehicleLabel': item.vehicleLabel!,
              if (item.title.trim().isNotEmpty) 'title': item.title,
            },
          ).toString(),
        );
        if (confirmed == true && mounted) {
          await _loadItinerary();
        }
        return;
      }
      if (isLivestream) {
        await context.push(
          Uri(
            path: '/livestream/setup',
            queryParameters: {
              'tourId': widget.tourId,
              'planItemId': item.planItemId,
              'fromItinerary': 'true',
              if (item.completed) 'retryStream': 'true',
            },
          ).toString(),
        );
      } else {
        final vehicleId = _resolveAttendanceVehicle(itinerary, item);
        await context.push(
          Uri(
            path: '/attendance/offline',
            queryParameters: {
              'tourId': widget.tourId,
              'planItemId': item.planItemId,
              if (item.checkpointId != null && item.checkpointId!.isNotEmpty)
                'checkpointId': item.checkpointId!,
              if (vehicleId.isNotEmpty) 'vehicleId': vehicleId,
              'sessionName': item.title,
              'autoStart': 'true',
              'fromItinerary': 'true',
            },
          ).toString(),
        );
      }
      if (mounted) {
        await _loadItinerary();
      }
    } finally {
      if (mounted) {
        setState(() => _openingPlanItemId = null);
      }
    }
  }

  List<Widget> _buildActivityContent(
    GuideTourItinerary itinerary,
    GuideItineraryActivityNode activity,
  ) {
    final children = <Widget>[];
    final checkpointIds = activity.checkpoints.map((cp) => cp.id).toList();
    final firstCheckpoint = activity.checkpoints.isNotEmpty
        ? activity.checkpoints.first
        : null;
    final lastCheckpoint = activity.checkpoints.isNotEmpty
        ? activity.checkpoints.last
        : null;

    // Giống web CheckpointsTab: ALIGHTING (xuống xe khi đến) → checkpoint →
    // livestream → BOARDING (lên xe khi rời).
    final alightingAtArrival = firstCheckpoint == null
        ? const <GuideTourItineraryItem>[]
        : itemsForAnchor(firstCheckpoint.id, itinerary.items)
              .where((item) => item.isAlighting)
              .toList();
    final livestreams = livestreamForActivity(
      activity.activityId,
      checkpointIds,
      itinerary.items,
    );
    final boardingAfterActivity = lastCheckpoint == null
        ? const <GuideTourItineraryItem>[]
        : itemsForAnchor(lastCheckpoint.id, itinerary.items)
              .where((item) => item.isBoardingAttendance)
              .toList();

    void addItemGroup(
      List<GuideTourItineraryItem> items, {
      String? fallbackCheckpointId,
    }) {
      if (items.isEmpty) return;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _TrailingItemsGroup(
          items: items,
          formatWindow: _formatWindow,
          openingPlanItemId: _openingPlanItemId,
          itinerary: itinerary,
          prepOpsLocked: _operationsLocked,
          fallbackCheckpointId: fallbackCheckpointId,
          onStartItem: (item) => _startItineraryItem(itinerary, item),
        ),
      );
    }

    addItemGroup(
      alightingAtArrival,
      fallbackCheckpointId: firstCheckpoint?.id,
    );

    for (var i = 0; i < activity.checkpoints.length; i++) {
      final checkpoint = activity.checkpoints[i];
      final isLast = i == activity.checkpoints.length - 1;
      final midItems = isLast
          ? const <GuideTourItineraryItem>[]
          : itemsForAnchor(checkpoint.id, itinerary.items)
                .where((item) => !item.isAlighting)
                .toList();

      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _CheckpointGroup(
          checkpoint: checkpoint,
          items: midItems,
          formatWindow: _formatWindow,
          openingPlanItemId: _openingPlanItemId,
          itinerary: itinerary,
          prepOpsLocked: _operationsLocked,
          onStartItem: (item) => _startItineraryItem(itinerary, item),
        ),
      );
    }

    addItemGroup(livestreams, fallbackCheckpointId: lastCheckpoint?.id);
    addItemGroup(
      boardingAfterActivity,
      fallbackCheckpointId: lastCheckpoint?.id,
    );

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = _itinerary;
    final tree = itinerary == null
        ? const <GuideItineraryTreeNode>[]
        : buildGuideItineraryTree(itinerary);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text(
          'Lịch trình tour',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _loadItinerary,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _GuideRoleScope(
        isTeacher: _isTeacher,
        child: Column(
        children: [
          if (_feedback != null)
            _TopFeedbackBanner(feedback: _feedback!, onDismiss: _clearFeedback),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadItinerary,
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _MessageCard(
                          icon: Icons.error_outline,
                          message: _error!,
                          color: Colors.red.shade700,
                        ),
                      ],
                    )
                  : itinerary == null ||
                        (itinerary.checkpoints.isEmpty &&
                            itinerary.items.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _MessageCard(
                          icon: Icons.event_busy_outlined,
                          message:
                              'Chưa có lịch trình vận hành cho xe của bạn trong tour này.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        if (_operationsLocked) ...[
                          const _PrepReadOnlyBanner(),
                          const SizedBox(height: 16),
                        ],
                        if (itinerary.vehicles.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final vehicle in itinerary.vehicles)
                                Chip(
                                  avatar: const Icon(
                                    Icons.directions_bus_outlined,
                                    size: 18,
                                  ),
                                  label: Text(vehicle.label),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          'Lịch trình theo điểm đến và hoạt động',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _operationsLocked
                              ? 'Xem địa điểm, hoạt động và mốc điểm danh/livestream — thao tác vận hành khóa đến ngày đi.'
                              : 'Hiển thị địa điểm, hoạt động và các mốc điểm danh/livestream của xe bạn — giống lịch trình trên web.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (itinerary.currentCheckpointId != null &&
                            itinerary.currentCheckpointId!.isNotEmpty) ...[
                          _CheckpointProgressBanner(
                            currentName: itinerary.currentCheckpointName ?? '—',
                            nextName: itinerary.nextCheckpointName,
                            completing: _completingCheckpoint,
                            operationsLocked: _operationsLocked,
                            onComplete: () =>
                                _completeCurrentCheckpoint(itinerary),
                            onLockedTap: _showPrepLockedSnack,
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final node in tree) ...[
                          if (node is GuideItineraryTerminalNode) ...[
                            _TerminalCheckpointCard(
                              checkpoint: node.checkpoint,
                              items: node.afterItems,
                              formatWindow: _formatWindow,
                              openingPlanItemId: _openingPlanItemId,
                              itinerary: itinerary,
                              prepOpsLocked: _operationsLocked,
                              onStartItem: (item) =>
                                  _startItineraryItem(itinerary, item),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (node is GuideItineraryDestinationNode)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DestinationItineraryCard(
                                destinationName: node.destinationName,
                                activityCount: node.activities.length,
                                children: [
                                  for (
                                    var i = 0;
                                    i < node.activities.length;
                                    i++
                                  )
                                    _ActivityBlock(
                                      activityName:
                                          node.activities[i].activityName,
                                      child: Column(
                                        children: _buildActivityContent(
                                          itinerary,
                                          node.activities[i],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _GuideRoleScope extends InheritedWidget {
  const _GuideRoleScope({
    required this.isTeacher,
    required super.child,
  });

  final bool isTeacher;

  static bool isTeacherOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_GuideRoleScope>()
            ?.isTeacher ??
        false;
  }

  @override
  bool updateShouldNotify(_GuideRoleScope oldWidget) {
    return isTeacher != oldWidget.isTeacher;
  }
}

class _ItineraryFeedback {
  const _ItineraryFeedback({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;
}

class _TopFeedbackBanner extends StatelessWidget {
  const _TopFeedbackBanner({required this.feedback, required this.onDismiss});

  final _ItineraryFeedback feedback;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final accent = feedback.isError
        ? const Color(0xFFDC2626)
        : AppTheme.accentGreen;
    final bg = feedback.isError
        ? const Color(0xFFFEF2F2)
        : AppTheme.accentGreen.withValues(alpha: 0.10);

    return Material(
      color: bg,
      elevation: 1,
      shadowColor: Colors.black26,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.25)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                feedback.isError
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feedback.message,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteCheckpointDialog extends StatelessWidget {
  const _CompleteCheckpointDialog({required this.currentName, this.nextName});

  final String currentName;
  final String? nextName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flag_circle_rounded,
                color: AppTheme.accentGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hoàn thành mốc này?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.neutral200),
              ),
              child: Column(
                children: [
                  _DialogStopRow(
                    label: 'Đang ở',
                    name: currentName,
                    emphasized: true,
                  ),
                  if (nextName != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    _DialogStopRow(label: 'Tiếp theo', name: nextName!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nextName == null
                  ? 'Xác nhận đã xong công việc tại mốc cuối. Sau đó điểm danh/livestream tại mốc này sẽ bị khóa.'
                  : 'Xác nhận đã xong công việc tại mốc hiện tại và chuyển sang mốc tiếp theo. Điểm danh/livestream của mốc này sẽ bị khóa.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: AppTheme.onSurface,
                      side: const BorderSide(color: AppTheme.neutral300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Để sau'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hoàn thành'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogStopRow extends StatelessWidget {
  const _DialogStopRow({
    required this.label,
    required this.name,
    this.emphasized = false,
  });

  final String label;
  final String name;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? AppTheme.accentGreen
                  : AppTheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasized ? 15 : 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrepReadOnlyBanner extends StatelessWidget {
  const _PrepReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accentOrange.withValues(alpha: 0.28),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            color: AppTheme.accentOrange,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tour sắp tới — chỉ xem kế hoạch, thao tác vận hành khóa đến ngày đi.',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckpointProgressBanner extends StatelessWidget {
  const _CheckpointProgressBanner({
    required this.currentName,
    required this.nextName,
    required this.completing,
    required this.onComplete,
    this.operationsLocked = false,
    this.onLockedTap,
  });

  final String currentName;
  final String? nextName;
  final bool completing;
  final VoidCallback onComplete;
  final bool operationsLocked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECKPOINT HIỆN TẠI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            operationsLocked
                ? 'Tour chưa tới ngày đi — chỉ xem mốc, chưa chốt được.'
                : nextName == null
                ? 'Đây là mốc cuối — hoàn thành khi xong công việc tại đây.'
                : 'Tiếp theo: $nextName',
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: operationsLocked
                ? OutlinedButton.icon(
                    onPressed: onLockedTap,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Khóa đến ngày đi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onSurfaceVariant,
                      side: const BorderSide(color: AppTheme.neutral300),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: completing ? null : onComplete,
                    icon: completing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      completing ? 'Đang lưu…' : 'Hoàn thành mốc này',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DestinationItineraryCard extends StatelessWidget {
  const _DestinationItineraryCard({
    required this.destinationName,
    required this.activityCount,
    required this.children,
  });

  final String destinationName;
  final int activityCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.neutral200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ĐIỂM ĐẾN',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destinationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activityCount hoạt động',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppTheme.surfaceLow,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBlock extends StatelessWidget {
  const _ActivityBlock({required this.activityName, required this.child});

  final String activityName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: AppTheme.neutral200)),
            ),
            child: Text(
              'Hoạt động · $activityName',
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

class _TerminalCheckpointCard extends StatelessWidget {
  const _TerminalCheckpointCard({
    required this.checkpoint,
    required this.items,
    required this.formatWindow,
    required this.onStartItem,
    required this.itinerary,
    this.openingPlanItemId,
    this.prepOpsLocked = false,
  });

  final GuideTourItineraryCheckpoint checkpoint;
  final List<GuideTourItineraryItem> items;
  final String Function(GuideTourItineraryItem item) formatWindow;
  final Future<void> Function(GuideTourItineraryItem item) onStartItem;
  final GuideTourItinerary itinerary;
  final String? openingPlanItemId;
  final bool prepOpsLocked;

  @override
  Widget build(BuildContext context) {
    final kind = checkpoint.kind.toUpperCase();
    final isPickup = kind == 'PICKUP';
    final isActive = _checkpointIsActive(checkpoint);
    final isCompleted = checkpoint.isCompleted;
    final statusLabel = _checkpointStatusLabel(checkpoint);
    final accentColor = _checkpointAccentColor(checkpoint);
    final time = checkpoint.plannedStart == null
        ? null
        : DateFormat('HH:mm').format(checkpoint.plannedStart!.toLocal());
    final sectionLabel = isPickup ? 'ĐƯA ĐÓN' : 'TRẢ HỌC SINH';
    final sectionIcon = isPickup
        ? Icons.directions_bus_outlined
        : Icons.home_work_outlined;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.04)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? accentColor
              : isCompleted
              ? AppTheme.accentGreen.withValues(alpha: 0.45)
              : AppTheme.neutral200,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor.withValues(alpha: 0.10)
                  : AppTheme.surfaceContainer,
              border: const Border(
                bottom: BorderSide(color: AppTheme.neutral200),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.16)
                        : AppTheme.secondary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(sectionIcon, size: 18, color: AppTheme.secondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionLabel,
                        style: const TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        checkpoint.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: isActive ? 16 : 15,
                          height: 1.25,
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$time · ${_checkpointKindLabel(kind)}',
                          style: const TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.accentGreen.withValues(alpha: 0.14)
                          : checkpoint.isArrived
                          ? AppTheme.accentOrange.withValues(alpha: 0.16)
                          : accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: isCompleted
                            ? AppTheme.accentGreen
                            : checkpoint.isArrived
                            ? AppTheme.accentOrange
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: items.isEmpty
                ? Text(
                    isPickup
                        ? 'Mốc đưa đón — không có thao tác bổ sung trên hệ thống.'
                        : 'Mốc trả học sinh — không có thao tác bổ sung trên hệ thống.',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  )
                : _NestedItemsColumn(
                    items: items,
                    formatWindow: formatWindow,
                    openingPlanItemId: openingPlanItemId,
                    itinerary: itinerary,
                    prepOpsLocked: prepOpsLocked,
                    onStartItem: onStartItem,
                  ),
          ),
        ],
      ),
    );
  }

  String _checkpointKindLabel(String kind) {
    return switch (kind.toUpperCase()) {
      'PICKUP' => 'Đón',
      'DROPOFF' => 'Trả',
      'MEAL' => 'Ăn uống',
      _ => 'Địa điểm',
    };
  }
}

class _CheckpointGroup extends StatelessWidget {
  const _CheckpointGroup({
    required this.checkpoint,
    required this.items,
    required this.formatWindow,
    required this.onStartItem,
    required this.itinerary,
    this.openingPlanItemId,
    this.prepOpsLocked = false,
  });

  final GuideTourItineraryCheckpoint checkpoint;
  final List<GuideTourItineraryItem> items;
  final String Function(GuideTourItineraryItem item) formatWindow;
  final Future<void> Function(GuideTourItineraryItem item) onStartItem;
  final GuideTourItinerary itinerary;
  final String? openingPlanItemId;
  final bool prepOpsLocked;

  @override
  Widget build(BuildContext context) {
    final time = checkpoint.plannedStart == null
        ? null
        : DateFormat('HH:mm').format(checkpoint.plannedStart!.toLocal());
    final isActive = _checkpointIsActive(checkpoint);
    final isCompleted = checkpoint.isCompleted;
    final statusLabel = _checkpointStatusLabel(checkpoint);
    final accentColor = _checkpointAccentColor(checkpoint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 10,
            vertical: isActive ? 12 : 9,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? accentColor.withValues(alpha: 0.10)
                : isCompleted
                ? AppTheme.accentGreen.withValues(alpha: 0.06)
                : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(isActive ? 12 : 8),
            border: Border.all(
              color: isActive
                  ? accentColor
                  : isCompleted
                  ? AppTheme.accentGreen.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle_outline
                    : checkpoint.isArrived
                    ? Icons.location_on_outlined
                    : isActive
                    ? Icons.my_location_rounded
                    : Icons.flag_outlined,
                size: isActive ? 18 : 16,
                color: isCompleted
                    ? AppTheme.accentGreen
                    : isActive
                    ? accentColor
                    : AppTheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isActive ? 14 : 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        ?time,
                        _checkpointKindLabel(checkpoint.kind),
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusLabel != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.accentGreen.withValues(alpha: 0.14)
                        : checkpoint.isArrived
                        ? AppTheme.accentOrange.withValues(alpha: 0.16)
                        : accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: isCompleted
                          ? AppTheme.accentGreen
                          : checkpoint.isArrived
                          ? AppTheme.accentOrange
                          : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          _NestedItemsColumn(
            items: items,
            formatWindow: formatWindow,
            openingPlanItemId: openingPlanItemId,
            itinerary: itinerary,
            prepOpsLocked: prepOpsLocked,
            onStartItem: onStartItem,
          ),
        ],
      ],
    );
  }

  String _checkpointKindLabel(String kind) {
    return switch (kind.toUpperCase()) {
      'PICKUP' => 'Đón',
      'DROPOFF' => 'Trả',
      'MEAL' => 'Ăn uống',
      _ => 'Địa điểm',
    };
  }
}

class _TrailingItemsGroup extends StatelessWidget {
  const _TrailingItemsGroup({
    required this.items,
    required this.formatWindow,
    required this.onStartItem,
    required this.itinerary,
    this.openingPlanItemId,
    this.fallbackCheckpointId,
    this.prepOpsLocked = false,
  });

  final List<GuideTourItineraryItem> items;
  final String Function(GuideTourItineraryItem item) formatWindow;
  final Future<void> Function(GuideTourItineraryItem item) onStartItem;
  final GuideTourItinerary itinerary;
  final String? openingPlanItemId;
  final String? fallbackCheckpointId;
  final bool prepOpsLocked;

  @override
  Widget build(BuildContext context) {
    return _NestedItemsColumn(
      items: items,
      formatWindow: formatWindow,
      openingPlanItemId: openingPlanItemId,
      itinerary: itinerary,
      fallbackCheckpointId: fallbackCheckpointId,
      prepOpsLocked: prepOpsLocked,
      onStartItem: onStartItem,
    );
  }
}

class _NestedItemsColumn extends StatelessWidget {
  const _NestedItemsColumn({
    required this.items,
    required this.formatWindow,
    required this.onStartItem,
    required this.itinerary,
    this.openingPlanItemId,
    this.fallbackCheckpointId,
    this.prepOpsLocked = false,
  });

  final List<GuideTourItineraryItem> items;
  final String Function(GuideTourItineraryItem item) formatWindow;
  final Future<void> Function(GuideTourItineraryItem item) onStartItem;
  final GuideTourItinerary itinerary;
  final String? openingPlanItemId;
  final String? fallbackCheckpointId;
  final bool prepOpsLocked;

  String? _anchorCheckpointId(GuideTourItineraryItem item) {
    final id = item.checkpointId;
    if (id != null && id.trim().isNotEmpty) return id;
    final fallback = fallbackCheckpointId;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return null;
  }

  /// null = operable; otherwise lock reason for UI copy.
  String? _checkpointLockReason(GuideTourItineraryItem item) {
    final anchorId = _anchorCheckpointId(item);
    if (anchorId == null) return null;
    if (itinerary.isCheckpointOperable(anchorId)) return null;
    if (itinerary.isCheckpointCompleted(anchorId)) {
      return 'completed';
    }
    return 'not_current';
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) tiles.add(const SizedBox(height: 8));
      final lockReason = _checkpointLockReason(items[i]);
      tiles.add(
        _NestedPlanItemTile(
          item: items[i],
          timeLabel: formatWindow(items[i]),
          opening: openingPlanItemId == items[i].planItemId,
          busy: openingPlanItemId != null,
          actionsLocked: lockReason != null,
          lockReason: lockReason,
          prepOpsLocked: prepOpsLocked,
          onStart: openingPlanItemId != null
              ? null
              : () => onStartItem(items[i]),
        ),
      );
    }
    return Column(children: tiles);
  }
}

class _NestedPlanItemTile extends StatelessWidget {
  const _NestedPlanItemTile({
    required this.item,
    required this.timeLabel,
    required this.onStart,
    this.opening = false,
    this.busy = false,
    this.actionsLocked = false,
    this.lockReason,
    this.prepOpsLocked = false,
  });

  final GuideTourItineraryItem item;
  final String timeLabel;
  final VoidCallback? onStart;
  final bool opening;
  final bool busy;
  final bool actionsLocked;

  /// `completed` | `not_current` when [actionsLocked] is true.
  final String? lockReason;
  final bool prepOpsLocked;

  @override
  Widget build(BuildContext context) {
    final isLivestream = item.isLivestream;
    final isAttendance = item.isAttendance;
    final isVehicleInspection = item.isVehicleInspection;
    final isTeacher = _GuideRoleScope.isTeacherOf(context);
    final isCompleted = item.completed;
    final inProgress =
        item.executionStatus.toUpperCase() == 'IN_PROGRESS' && !isCompleted;
    final lockedAsCompleted = actionsLocked && lockReason == 'completed';
    final lockedAsNotCurrent = actionsLocked && lockReason == 'not_current';
    // Once the checkpoint is completed, no reopen attendance/livestream.
    final canRetryAttendance =
        isAttendance && isCompleted && !actionsLocked && !prepOpsLocked;
    final canRetryLivestream =
        isLivestream && isCompleted && !actionsLocked && !prepOpsLocked;
    final canRetry = canRetryAttendance || canRetryLivestream;
    final showTeacherInspection =
        isVehicleInspection && isTeacher && !isCompleted && !actionsLocked;
    final showPrepLockedAction =
        prepOpsLocked &&
        !actionsLocked &&
        ((isVehicleInspection && isTeacher && !isCompleted) ||
            (!isVehicleInspection && (isAttendance || isLivestream)));
    final showAction =
        showPrepLockedAction ||
        (!prepOpsLocked &&
            (showTeacherInspection ||
                (!isVehicleInspection &&
                    !actionsLocked &&
                    (!isCompleted || canRetry))));
    final accent = prepOpsLocked && !actionsLocked
        ? AppTheme.onSurfaceVariant
        : isVehicleInspection
        ? (isCompleted ? AppTheme.accentGreen : AppTheme.cta)
        : lockedAsCompleted
        ? AppTheme.accentGreen
        : lockedAsNotCurrent
        ? AppTheme.onSurfaceVariant
        : canRetryLivestream
        ? Colors.deepOrange.shade700
        : isCompleted
        ? AppTheme.accentGreen
        : isLivestream
        ? Colors.red.shade600
        : AppTheme.accentGreen;

    String actionLabel() {
      if (prepOpsLocked) return 'Khóa đến ngày đi';
      if (opening) return 'Đang mở…';
      if (showTeacherInspection) return 'Kiểm tra & xác nhận xe';
      if (canRetryLivestream) return 'Phát sóng lại · lần 2+';
      if (isLivestream && inProgress) return 'Tiếp tục phát sóng';
      if (isLivestream) return 'Bắt đầu phát sóng';
      if (canRetryAttendance) return 'Mở phiên mới';
      if (inProgress) return 'Tiếp tục điểm danh';
      return 'Bắt đầu điểm danh';
    }

    String statusChipLabel() {
      if (prepOpsLocked && !actionsLocked) return 'Chưa tới ngày đi';
      if (isVehicleInspection && isCompleted) return 'Đã xác nhận';
      if (isVehicleInspection && lockedAsNotCurrent) {
        return 'Chỉ thao tác mốc hiện tại';
      }
      if (isVehicleInspection) {
        return isTeacher ? 'Chờ bạn xác nhận' : 'Chờ giáo viên xác nhận';
      }
      if (lockedAsNotCurrent &&
          (isAttendance || isLivestream || isVehicleInspection)) {
        return 'Chỉ thao tác mốc hiện tại';
      }
      if (lockedAsCompleted && (isAttendance || isLivestream)) {
        return isCompleted ? 'Đã khóa theo mốc' : 'Mốc đã hoàn thành';
      }
      if (canRetryLivestream) return 'Đã phát · mở lại được';
      if (isCompleted) return 'Hoàn thành';
      return item.executionStatusLabel;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted
              ? AppTheme.accentGreen.withValues(alpha: 0.35)
              : isVehicleInspection
              ? Colors.amber.shade200
              : AppTheme.neutral200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                prepOpsLocked && !actionsLocked
                    ? Icons.lock_outline
                    : isVehicleInspection
                    ? Icons.pending_actions_outlined
                    : canRetryLivestream
                    ? Icons.replay_circle_filled_outlined
                    : isCompleted
                    ? Icons.check_circle_outline
                    : isLivestream
                    ? Icons.videocam_outlined
                    : Icons.fact_check_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: statusChipLabel(), color: accent),
            ],
          ),
          if ((item.vehicleLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Xe: ${item.vehicleLabel}',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                item.itemKindLabel,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              if (item.required) ...[
                const SizedBox(width: 8),
                const Text(
                  '· Bắt buộc',
                  style: TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
              if (isVehicleInspection) ...[
                const SizedBox(width: 8),
                const Text(
                  '· Giáo viên',
                  style: TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          if (isVehicleInspection) ...[
            const SizedBox(height: 8),
            Text(
              isTeacher
                  ? 'Xác nhận checklist an toàn xe và ký bằng OTP trước khi tour vận hành.'
                  : 'Giáo viên sẽ xác nhận tình trạng xe. HDV không thao tác bước này '
                      'và không cần chờ để chuyển checkpoint.',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (prepOpsLocked && !actionsLocked) ...[
            const SizedBox(height: 8),
            Text(
              'Tour chưa tới ngày đi — chỉ xem kế hoạch.',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (lockedAsNotCurrent &&
              (isAttendance || isLivestream || isVehicleInspection)) ...[
            const SizedBox(height: 8),
            Text(
              'Chỉ thao tác mốc hiện tại',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (lockedAsCompleted &&
              !isVehicleInspection &&
              (isAttendance || isLivestream)) ...[
            const SizedBox(height: 8),
            Text(
              'Mốc đã hoàn thành — không mở lại điểm danh/livestream.',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (showAction) ...[
            if (canRetryAttendance) ...[
              const SizedBox(height: 8),
              Text(
                'Có thể mở phiên điểm danh mới để cập nhật hoặc bổ sung.',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
            if (canRetryLivestream) ...[
              const SizedBox(height: 8),
              Text(
                'Mốc này đã phát sóng xong. Bấm để mở livestream lần tiếp theo '
                '(phiên mới, khác lần trước).',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.9),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: prepOpsLocked
                  ? OutlinedButton.icon(
                      onPressed: busy ? null : onStart,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: AppTheme.onSurfaceVariant,
                        side: const BorderSide(color: AppTheme.neutral300),
                      ),
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: Text(
                        actionLabel(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  : canRetry
                  ? OutlinedButton.icon(
                      onPressed: busy ? null : onStart,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: canRetryLivestream
                            ? Colors.deepOrange.shade700
                            : AppTheme.secondary,
                        side: BorderSide(
                          color: canRetryLivestream
                              ? Colors.deepOrange.shade300
                              : AppTheme.neutral300,
                        ),
                      ),
                      icon: opening
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              canRetryLivestream
                                  ? Icons.videocam_outlined
                                  : Icons.replay_rounded,
                              size: 18,
                            ),
                      label: Text(
                        actionLabel(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: busy ? null : onStart,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: showTeacherInspection
                            ? AppTheme.cta
                            : null,
                      ),
                      icon: opening
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              showTeacherInspection
                                  ? Icons.verified_user_outlined
                                  : isLivestream
                                  ? Icons.play_arrow_rounded
                                  : Icons.fact_check_outlined,
                              size: 18,
                            ),
                      label: Text(
                        actionLabel(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.color});

  final IconData icon;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppTheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: resolvedColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: resolvedColor, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
