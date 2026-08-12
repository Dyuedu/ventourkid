import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../../parent/data/models/parent_dashboard_api_models.dart';

class ToursPage extends ConsumerStatefulWidget {
  const ToursPage({super.key, this.initialTab = 'live'});

  /// live | upcoming | past
  final String initialTab;

  @override
  ConsumerState<ToursPage> createState() => _ToursPageState();
}

class _ToursPageState extends ConsumerState<ToursPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<LinkedChildModel> _children = const [];
  String? _selectedRosterStudentId;
  List<Map<String, dynamic>> _upcoming = const [];
  List<Map<String, dynamic>> _live = const [];
  List<Map<String, dynamic>> _past = const [];
  bool _loading = true;
  String? _error;

  static const _tabKeys = ['upcoming', 'live', 'past'];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabKeys.indexOf(widget.initialTab);
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex < 0 ? 1 : initialIndex,
    );
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final remote = ref.read(parentDashboardRemoteDataSourceProvider);
      final children = await remote.getLinkedChildren();
      if (!mounted) return;
      if (children.isEmpty) {
        setState(() {
          _children = const [];
          _selectedRosterStudentId = null;
          _upcoming = const [];
          _live = const [];
          _past = const [];
          _loading = false;
        });
        return;
      }
      final selected = children.firstWhere(
        (c) => c.rosterStudentId == _selectedRosterStudentId,
        orElse: () => children.first,
      );
      setState(() {
        _children = children;
        _selectedRosterStudentId = selected.rosterStudentId;
      });
      await _loadTours(selected.rosterStudentId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được danh sách tour của con.';
      });
    }
  }

  Future<void> _loadTours(String rosterStudentId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final remote = ref.read(parentDashboardRemoteDataSourceProvider);
      final payload = await remote.listChildTours(
        rosterStudentId: rosterStudentId,
      );
      if (!mounted) return;
      setState(() {
        _upcoming = List<Map<String, dynamic>>.from(
          payload['upcoming'] as List? ?? const [],
        );
        _live = List<Map<String, dynamic>>.from(
          payload['live'] as List? ?? const [],
        );
        _past = List<Map<String, dynamic>>.from(
          payload['past'] as List? ?? const [],
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được chuyến đi của học sinh đã chọn.';
      });
    }
  }

  String _childLabel(LinkedChildModel child) => child.displayLabel;

  String _tourName(Map<String, dynamic> tour) =>
      (tour['tour_name'] ?? tour['tourName'] ?? 'Chuyến đi trải nghiệm')
          .toString();

  String _tourId(Map<String, dynamic> tour) =>
      (tour['tour_id'] ?? tour['tourId'] ?? '').toString();

  String _dateLabel(Map<String, dynamic> tour) {
    final raw = tour['planned_date'] ?? tour['date'] ?? tour['plannedDate'];
    if (raw == null) return 'Chưa có ngày';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  String _statusLabel(Map<String, dynamic> tour, String bucket) {
    final plan = (tour['plan_status'] ?? tour['planStatus'] ?? '').toString();
    if (bucket == 'live') return 'Đang vận hành';
    if (bucket == 'past') return 'Đã hoàn tất';
    if (plan.isEmpty) return 'Đang chuẩn bị';
    return 'Chuẩn bị · $plan';
  }

  Future<void> _openTour(Map<String, dynamic> tour, {required bool isPast}) async {
    final tourId = _tourId(tour);
    final rosterId = _selectedRosterStudentId;
    if (rosterId == null || rosterId.isEmpty) return;

    if (isPast) {
      LinkedChildModel? selected;
      for (final child in _children) {
        if (child.rosterStudentId == rosterId) {
          selected = child;
          break;
        }
      }
      final uri = Uri(
        path: '/parent/tour-history',
        queryParameters: {
          if (tourId.isNotEmpty) 'tourId': tourId,
          'child': rosterId,
          if (selected != null && _childLabel(selected).isNotEmpty)
            'childName': _childLabel(selected),
        },
      );
      if (!mounted) return;
      await context.push(uri.toString(), extra: tour);
      return;
    }

    // Focus dashboard on this child + tour via query for home reload.
    if (!mounted) return;
    context.go(
      Uri(
        path: '/parent/dashboard',
        queryParameters: {
          'rosterStudentId': rosterId,
          if (tourId.isNotEmpty) 'tourId': tourId,
        },
      ).toString(),
    );
  }

  Widget _buildTourList(List<Map<String, dynamic>> tours, String bucket) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ParentEmptyState(
        icon: Icons.error_outline,
        title: 'Không tải được',
        description: _error!,
        actionLabel: 'Thử lại',
        onAction: _bootstrap,
      );
    }
    if (_children.isEmpty) {
      return const ParentEmptyState(
        icon: Icons.child_care_outlined,
        title: 'Chưa liên kết học sinh',
        description:
            'Hãy liên kết con trước để xem tour đang chuẩn bị, đang chạy và lịch sử.',
      );
    }
    if (tours.isEmpty) {
      final emptyTitle = switch (bucket) {
        'live' => 'Không có tour đang vận hành',
        'upcoming' => 'Chưa có tour sắp tới',
        _ => 'Chưa có lịch sử tour',
      };
      final emptyDesc = switch (bucket) {
        'live' => 'Khi tour của con chuyển sang vận hành sẽ hiện tại đây.',
        'upcoming' =>
          'Các tour đang chuẩn bị / sẵn sàng của con sẽ hiện tại đây để bạn chuyển xem.',
        _ =>
          'Tour đã hoàn tất của học sinh đang chọn sẽ được lưu tại đây.',
      };
      return ParentEmptyState(
        icon: Icons.route_outlined,
        title: emptyTitle,
        description: emptyDesc,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tours.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tour = tours[index];
        final isPast = bucket == 'past';
        return Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openTour(tour, isPast: isPast),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neutral200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bucket == 'live'
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.secondaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      bucket == 'live'
                          ? Icons.play_circle_outline
                          : bucket == 'past'
                              ? Icons.history
                              : Icons.event_available_outlined,
                      color: bucket == 'live'
                          ? AppTheme.primary
                          : AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tourName(tour),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateLabel(tour),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _StatusChip(label: _statusLabel(tour, bucket)),
                            if (isPast)
                              const _StatusChip(label: 'Của con đang chọn'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final LinkedChildModel? selectedChild = () {
      for (final child in _children) {
        if (child.rosterStudentId == _selectedRosterStudentId) return child;
      }
      return _children.isEmpty ? null : _children.first;
    }();

    return ParentPageScaffold(
      title: 'Chuyến đi của con',
      leading: buildAppBackLeading(context),
      body: Column(
        children: [
          if (_children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Học sinh',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        final selected =
                            child.rosterStudentId == _selectedRosterStudentId;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(_childLabel(child)),
                          onSelected: (_) async {
                            setState(() {
                              _selectedRosterStudentId = child.rosterStudentId;
                            });
                            await _loadTours(child.rosterStudentId);
                          },
                        );
                      },
                    ),
                  ),
                  if (selectedChild != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tour gắn với ${_childLabel(selectedChild)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Sắp tới (${_upcoming.length})'),
              Tab(text: 'Đang chạy (${_live.length})'),
              Tab(text: 'Đã qua (${_past.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildTourList(_upcoming, 'upcoming'),
                _buildTourList(_live, 'live'),
                _buildTourList(_past, 'past'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
