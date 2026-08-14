import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../domain/entities/tour_attendance_history.dart';

class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({
    super.key,
    required this.tourId,
    this.tourName,
    this.initialPlanItemId,
    this.initialActivityName,
    this.initialDestinationName,
    this.initialCheckpointId,
  });

  final String tourId;
  final String? tourName;
  final String? initialPlanItemId;
  final String? initialActivityName;
  final String? initialDestinationName;
  final String? initialCheckpointId;

  @override
  ConsumerState<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends ConsumerState<AttendanceHistoryPage> {
  final _searchController = TextEditingController();
  TourAttendanceHistory? _history;
  bool _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'ALL';
  String? _selectedPlanItemId;

  @override
  void initState() {
    super.initState();
    _selectedPlanItemId = widget.initialPlanItemId;
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final planItemChanged =
        (oldWidget.initialPlanItemId ?? '').trim().toLowerCase() !=
        (widget.initialPlanItemId ?? '').trim().toLowerCase();
    final checkpointChanged =
        (oldWidget.initialCheckpointId ?? '').trim() !=
        (widget.initialCheckpointId ?? '').trim();
    if (oldWidget.tourId != widget.tourId ||
        planItemChanged ||
        checkpointChanged) {
      _searchController.clear();
      _query = '';
      _statusFilter = 'ALL';
      _selectedPlanItemId = widget.initialPlanItemId;
      Future.microtask(_load);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.tourId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Thiếu mã tour để xem lịch sử điểm danh.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _history = null;
      _selectedPlanItemId = widget.initialPlanItemId;
    });
    try {
      final history = await ref
          .read(offlineAttendanceRepositoryProvider)
          .getTourAttendanceHistory(
            widget.tourId,
            planItemId: widget.initialPlanItemId,
          );
      if (!mounted) return;
      setState(() {
        _history = _resolveHistory(history);
        _selectedPlanItemId = _history!.activities.length == 1
            ? _history!.activities.first.planItemId
            : _lockToPlanItem
            ? widget.initialPlanItemId
            : _preferredActivityId(_history!);
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  TourAttendanceHistory _resolveHistory(TourAttendanceHistory history) {
    if (!_lockToPlanItem) return history;
    final scoped = history.scopedToPlanItem(widget.initialPlanItemId);
    if (scoped.activities.isNotEmpty) return scoped;
    if (history.activities.length == 1) return history;
    return scoped;
  }

  String? _preferredActivityId(TourAttendanceHistory history) {
    if (history.activities.isEmpty) return null;
    final initialId = (widget.initialPlanItemId ?? '').trim();
    if (initialId.isNotEmpty) {
      for (final activity in history.activities) {
        if (samePlanItemId(activity.planItemId, initialId)) {
          return activity.planItemId;
        }
      }
      return initialId;
    }
    for (final activity in history.activities) {
      if (activity.countOf('pending') > 0) return activity.planItemId;
    }
    return history.activities.first.planItemId;
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool get _lockToPlanItem =>
      (widget.initialPlanItemId ?? '').trim().isNotEmpty;

  TourAttendanceActivityHistory? get _selectedActivity {
    final history = _history;
    if (history == null || history.activities.isEmpty) return null;
    if (_lockToPlanItem && history.activities.length == 1) {
      return history.activities.first;
    }
    final wantedId = _lockToPlanItem
        ? widget.initialPlanItemId
        : _selectedPlanItemId;
    for (final activity in history.activities) {
      if (samePlanItemId(activity.planItemId, wantedId)) {
        return activity;
      }
    }
    if (_lockToPlanItem) return null;
    return history.activities.first;
  }

  bool _activityHasRecords(TourAttendanceActivityHistory activity) {
    if (activity.sessions.isNotEmpty) return true;
    return activity.students.any(
      (student) =>
          student.recordedAt != null || student.normalizedStatus != 'PENDING',
    );
  }

  List<TourAttendanceStudentHistory> _studentsMatchingSearch(
    TourAttendanceActivityHistory activity,
  ) {
    final keyword = _query.trim().toLowerCase();
    return activity.students.where((student) {
      if (keyword.isEmpty) return true;
      return [
        student.fullName,
        student.className,
        student.studentCode,
        student.vehicleLabel,
      ].whereType<String>().any((value) => value.toLowerCase().contains(keyword));
    }).toList();
  }

  List<TourAttendanceStudentHistory> _visibleStudents(
    TourAttendanceActivityHistory activity,
  ) {
    final students = _studentsMatchingSearch(activity).where((student) {
      if (_statusFilter == 'ALL') return true;
      return student.normalizedStatus == _statusFilter;
    }).toList();
    students.sort((a, b) {
      final rank = _statusRank(a.normalizedStatus)
          .compareTo(_statusRank(b.normalizedStatus));
      if (rank != 0) return rank;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return students;
  }

  Map<String, int> _statusCounts(TourAttendanceActivityHistory activity) {
    final students = _studentsMatchingSearch(activity);
    return {
      'ALL': students.length,
      'PRESENT': students
          .where((student) => student.normalizedStatus == 'PRESENT')
          .length,
      'ABSENT': students
          .where((student) => student.normalizedStatus == 'ABSENT')
          .length,
      'PENDING': students
          .where((student) => student.normalizedStatus == 'PENDING')
          .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final destination = (widget.initialDestinationName ?? '').trim();
    final activityName = (widget.initialActivityName ?? '').trim();
    final lockedTitle = [
      if (destination.isNotEmpty) destination,
      if (activityName.isNotEmpty) activityName,
    ].join(' · ');
    final title = _lockToPlanItem && lockedTitle.isNotEmpty
        ? lockedTitle
        : _history?.tourName ?? widget.tourName ?? 'Lịch sử điểm danh';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lịch sử điểm danh'),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _history == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _history == null) {
      return _MessageState(
        icon: Iconsax.warning_2,
        color: AppTheme.accentRed,
        message: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
        onRefresh: _load,
      );
    }

    final history = _history!;
    if (history.activities.isEmpty) {
      return _MessageState(
        icon: Iconsax.user_octagon,
        message: _lockToPlanItem
            ? 'Chưa có lịch sử điểm danh cho mốc này.'
            : 'Tour chưa có hoạt động điểm danh.',
        onRefresh: _load,
      );
    }

    final activity = _selectedActivity;
    if (activity == null ||
        (_lockToPlanItem && !_activityHasRecords(activity))) {
      return _MessageState(
        icon: Iconsax.user_octagon,
        message: _lockToPlanItem
            ? 'Chưa có lịch sử điểm danh cho mốc này.'
            : 'Tour chưa có hoạt động điểm danh.',
        onRefresh: _load,
      );
    }

    final students = _visibleStudents(activity);
    final counts = _statusCounts(activity);
    final searching = _query.trim().isNotEmpty;
    final entries = _listEntries(students);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm tên, lớp, xe…',
              prefixIcon: const Icon(Iconsax.search_normal_1, size: 20),
              suffixIcon: searching
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Iconsax.close_circle, size: 20),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.neutral200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.neutral200),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _StatusFilterBar(
          selected: _statusFilter,
          counts: counts,
          onSelected: (value) {
            HapticFeedback.selectionClick();
            setState(() => _statusFilter = value);
          },
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _load,
            child: students.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
                    children: [
                      Icon(
                        searching ? Iconsax.search_status : Iconsax.people,
                        size: 36,
                        color: AppTheme.neutral400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _emptyMessage(searching),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      if (searching || _statusFilter != 'ALL') ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _statusFilter = 'ALL';
                              });
                            },
                            child: const Text('Xóa bộ lọc'),
                          ),
                        ),
                      ],
                    ],
                  )
                : ListView.builder(
                    key: ValueKey('${activity.planItemId}-$_statusFilter-$_query'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry.header != null) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(4, index == 0 ? 4 : 14, 4, 8),
                          child: Text(
                            entry.header!,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.neutral500,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }
                      final student = entry.student!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StudentRow(
                          key: ValueKey(student.rosterStudentId),
                          student: student,
                          onTap: () => _openStudentDetail(activity, student),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<_ListEntry> _listEntries(List<TourAttendanceStudentHistory> students) {
    if (_statusFilter != 'ALL') {
      return [
        _ListEntry.header('${_statusLabel(_statusFilter)} (${students.length})'),
        ...students.map(_ListEntry.student),
      ];
    }
    final grouped = <String, List<TourAttendanceStudentHistory>>{
      'PENDING': [],
      'ABSENT': [],
      'PRESENT': [],
    };
    for (final student in students) {
      grouped.putIfAbsent(student.normalizedStatus, () => []).add(student);
    }
    final entries = <_ListEntry>[];
    for (final status in const ['PENDING', 'ABSENT', 'PRESENT']) {
      final group = grouped[status] ?? const [];
      if (group.isEmpty) continue;
      entries.add(_ListEntry.header('${_statusLabel(status)} (${group.length})'));
      entries.addAll(group.map(_ListEntry.student));
    }
    return entries;
  }

  String _emptyMessage(bool searching) {
    if (searching) return 'Không có học sinh khớp trong hoạt động đang chọn.';
    if (_statusFilter == 'PENDING') {
      return 'Hoạt động này không còn học sinh chưa điểm danh.';
    }
    if (_statusFilter == 'ABSENT') {
      return 'Không có học sinh vắng trong hoạt động này.';
    }
    if (_statusFilter == 'PRESENT') {
      return 'Chưa có học sinh được ghi có mặt.';
    }
    return 'Không có học sinh trong hoạt động này.';
  }

  void _openStudentDetail(
    TourAttendanceActivityHistory activity,
    TourAttendanceStudentHistory student,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StudentDetailSheet(
        activity: activity,
        student: student,
      ),
    );
  }
}

class _ListEntry {
  const _ListEntry.header(this.header) : student = null;
  const _ListEntry.student(this.student) : header = null;

  final String? header;
  final TourAttendanceStudentHistory? student;
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.onRefresh,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(icon, size: 40, color: color ?? AppTheme.neutral400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            Center(
              child: FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('ALL', 'Tất cả'),
      ('PENDING', 'Chưa'),
      ('ABSENT', 'Vắng'),
      ('PRESENT', 'Có mặt'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = items[index].$1;
          final label = items[index].$2;
          final count = counts[key] ?? 0;
          final isSelected = selected == key;
          return Semantics(
            button: true,
            selected: isSelected,
            label: '$label $count',
            child: Material(
              color: isSelected ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                onTap: () => onSelected(key),
                borderRadius: BorderRadius.circular(99),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        '$label $count',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    super.key,
    required this.student,
    required this.onTap,
  });

  final TourAttendanceStudentHistory student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = student.normalizedStatus;
    final accent = _statusColor(status);
    final subtitle = [
      if ((student.className ?? '').trim().isNotEmpty) 'Lớp ${student.className}',
      student.vehicleLabel,
      if (student.recordedAt != null)
        DateFormat('HH:mm').format(student.recordedAt!.toLocal()),
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label: '${student.fullName}. ${_statusLabel(status)}. '
          'Bấm để xem chi tiết điểm danh.',
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: accent.withValues(alpha: 0.12),
                            child: Text(
                              _initials(student.fullName),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  student.fullName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.ink,
                                      ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          _StatusChip(status: status),
                          const SizedBox(width: 2),
                          const Icon(
                            Iconsax.arrow_right_3,
                            size: 16,
                            color: AppTheme.neutral400,
                          ),
                        ],
                      ),
                    ),
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

class _StudentDetailSheet extends StatelessWidget {
  const _StudentDetailSheet({
    required this.activity,
    required this.student,
  });

  final TourAttendanceActivityHistory activity;
  final TourAttendanceStudentHistory student;

  @override
  Widget build(BuildContext context) {
    final marked = student.recordedAt != null;
    final attendanceRows = <(String, String)>[
      if (_hasText(student.markedByName))
        ('Người điểm danh', student.markedByName!),
      if (_hasText(_methodLabel(student.method, allowEmpty: true)))
        ('Phương thức', _methodLabel(student.method)),
      if (student.confidence != null)
        ('Độ tin cậy', _confidenceLabel(student.confidence)),
      if (_hasText(student.sessionName))
        ('Phiên điểm danh', student.sessionName!),
      if (_hasText(student.overrideReason))
        ('Lý do ghi đè', student.overrideReason!),
    ];
    final studentRows = <(String, String)>[
      if (_displayStudentCode(student.studentCode) != null)
        ('Mã học sinh', _displayStudentCode(student.studentCode)!),
      if (_hasText(_genderLabel(student.gender, allowEmpty: true)))
        ('Giới tính', _genderLabel(student.gender)),
      if (_hasText(student.className)) ('Lớp', student.className!),
      if (_hasText(student.vehicleLabel)) ('Xe', student.vehicleLabel!),
      ('Hoạt động', activity.displayTitle),
      if (_hasText(activity.destinationName))
        ('Điểm đến', activity.destinationName!),
      if (_hasText(activity.checkpointName))
        ('Mốc điểm danh', activity.checkpointName!),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.56,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.neutral200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      student.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusChip(status: student.normalizedStatus),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _statusColor(student.normalizedStatus)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marked
                          ? DateFormat('HH:mm').format(student.recordedAt!.toLocal())
                          : 'Chưa điểm danh',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marked
                          ? [
                              if (student.recordedAt != null)
                                DateFormat('dd/MM/yyyy')
                                    .format(student.recordedAt!.toLocal()),
                              if (_hasText(student.markedByName))
                                student.markedByName,
                            ].whereType<String>().join(' · ')
                          : 'Học sinh này chưa được ghi nhận ở hoạt động hiện tại.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (attendanceRows.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DetailGroup(title: 'Điểm danh', rows: attendanceRows),
              ],
              const SizedBox(height: 14),
              _DetailGroup(title: 'Thông tin học sinh', rows: studentRows),
            ],
          ),
        );
      },
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.neutral500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            Text(
              rows[i].$1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.neutral500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rows[i].$2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            if (i < rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

int _statusRank(String status) {
  return switch (status) {
    'PENDING' => 0,
    'ABSENT' => 1,
    _ => 2,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'PRESENT' => 'Có mặt',
    'ABSENT' => 'Vắng',
    'PENDING' => 'Chưa điểm danh',
    _ => 'Chưa điểm danh',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'PRESENT' => AppTheme.accentGreen,
    'ABSENT' => AppTheme.accentRed,
    _ => AppTheme.accentOrange,
  };
}

bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'HS';
  String firstChar(String value) =>
      value.isEmpty ? '' : value.substring(0, 1).toUpperCase();
  if (parts.length == 1) return firstChar(parts.first);
  return '${firstChar(parts[parts.length - 2])}${firstChar(parts.last)}';
}

String _methodLabel(String? method, {bool allowEmpty = false}) {
  switch ((method ?? '').toUpperCase()) {
    case 'FACE':
    case 'FACE_RECOGNITION':
      return 'Khuôn mặt';
    case 'LOW_CONFIDENCE':
      return 'Khuôn mặt (độ tin cậy thấp)';
    case 'MANUAL':
    case 'MANUAL_OVERRIDE':
      return 'Thủ công';
    case 'OFFLINE':
    case 'OFFLINE_SYNC':
      return 'Offline';
    case 'NOT_MATCHED':
      return 'Không khớp';
    case 'MANUAL_REQUIRED':
      return allowEmpty ? '' : 'Chưa điểm danh';
    default:
      if (method == null || method.isEmpty) return allowEmpty ? '' : '—';
      return method;
  }
}

String _genderLabel(String? gender, {bool allowEmpty = false}) {
  switch ((gender ?? '').toUpperCase()) {
    case 'MALE':
    case 'NAM':
      return 'Nam';
    case 'FEMALE':
    case 'NỮ':
    case 'NU':
      return 'Nữ';
    default:
      if (allowEmpty && (gender == null || gender.isEmpty)) return '';
      return (gender == null || gender.isEmpty) ? '—' : gender;
  }
}

String _confidenceLabel(double? value) {
  if (value == null) return '—';
  return '${(value * 100).round()}%';
}

String? _displayStudentCode(String? code) {
  if (code == null || code.isEmpty) return null;
  if (RegExp(r'^[a-f0-9]{32,}$', caseSensitive: false).hasMatch(code)) {
    return null;
  }
  return code;
}
