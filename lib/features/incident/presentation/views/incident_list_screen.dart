import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../domain/entities/incident_status.dart';
import '../widgets/incident_card.dart';

/// Screen 3.2.43 — Incident Management (Guide/Teacher list view).
class IncidentListScreen extends ConsumerStatefulWidget {
  const IncidentListScreen({
    super.key,
    required this.tourId,
    this.readOnly = false,
  });

  final String tourId;

  /// When true (tour COMPLETED), hide create FAB — view existing reports only.
  final bool readOnly;

  @override
  ConsumerState<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends ConsumerState<IncidentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: 'Tất cả', status: null),
    (label: 'Mới', status: IncidentStatus.open),
    (label: 'Đang xử lý', status: IncidentStatus.acknowledged),
    (label: 'Leo thang', status: IncidentStatus.escalated),
    (label: 'Đã giải quyết', status: IncidentStatus.resolved),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIncidents());
  }

  Future<void> _loadIncidents() async {
    if (widget.tourId.isEmpty) return;
    await ref
        .read(incidentViewModelProvider.notifier)
        .loadIncidentsByTour(widget.tourId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context, color: AppTheme.primary),
        title: const Text('Quản lý sự cố'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.primary,
          tabs: _tabs
              .map(
                (t) => Tab(
                  child: Text(t.label, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
        ),
      ),
      body: widget.tourId.isEmpty
          ? Center(
              child: Text(
                'Không xác định được tour hiện tại.',
                style: TextStyle(color: AppTheme.onSurfaceVariant),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: _tabs
                  .map(
                    (t) => _IncidentTabBody(
                      statusFilter: t.status,
                      onRefresh: _loadIncidents,
                      readOnly: widget.readOnly,
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: widget.tourId.isEmpty || widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/incident/create?tourId=${widget.tourId}'),
              backgroundColor: AppTheme.cta,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text(
                'Báo cáo sự cố',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      bottomNavigationBar: widget.readOnly
          ? SafeArea(
              child: Material(
                color: AppTheme.neutral100,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tour đã hoàn tất — chỉ xem sự cố đã ghi. Không thể tạo báo cáo mới.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _IncidentTabBody extends ConsumerWidget {
  const _IncidentTabBody({
    required this.statusFilter,
    required this.onRefresh,
    this.readOnly = false,
  });

  final IncidentStatus? statusFilter;
  final Future<void> Function() onRefresh;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incidentViewModelProvider);

    if (state.isLoadingList && state.incidents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.incidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final incidents = statusFilter == null
        ? state.incidents
        : state.incidents
              .where((incident) => incident.status == statusFilter)
              .toList();

    if (incidents.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          children: const [
            ParentEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Chưa có sự cố',
              description: 'Chưa có sự cố nào trong mục này.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: incidents.length,
        itemBuilder: (context, index) =>
            IncidentCard(
              incident: incidents[index],
              readOnly: readOnly,
            ),
      ),
    );
  }
}
