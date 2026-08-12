import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../data/models/notification_models.dart';
import '../controllers/notification_realtime_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<AppNotification> _items = const [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationRealtimeProvider.notifier).start();
      await _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(notificationRemoteDataSourceProvider)
          .listInbox(filter: _filter);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _unreadCount = page.unreadCount;
      });
      ref
          .read(notificationRealtimeProvider.notifier)
          .setUnreadCount(page.unreadCount);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRemoteDataSourceProvider).markAllRead();
      ref.read(notificationRealtimeProvider.notifier).setUnreadCount(0);
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openItem(AppNotification item) async {
    if (!item.read) {
      try {
        await ref
            .read(notificationRemoteDataSourceProvider)
            .markRead(item.recipientId);
        final next = (_unreadCount - 1).clamp(0, 9999);
        ref.read(notificationRealtimeProvider.notifier).setUnreadCount(next);
      } on Object {
        // Still allow navigation even if mark-read fails.
      }
    }

    if (!mounted) return;
    final path = item.mobileActionPath;
    if (path != null && path.startsWith('/') && !path.startsWith('http')) {
      if (path.startsWith('/guide/') ||
          path.startsWith('/livestream/') ||
          path.startsWith('/attendance/') ||
          path.startsWith('/incident') ||
          path.startsWith('/tracking')) {
        context.push(path);
        await _load();
        return;
      }
    }
    if (item.tourId != null && item.tourId!.isNotEmpty) {
      context.push('/guide/itinerary?tourId=${item.tourId}');
      await _load();
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationRealtimeState>(notificationRealtimeProvider, (
      previous,
      next,
    ) {
      if (previous?.revision == next.revision) return;
      if (next.unreadCount != _unreadCount) {
        setState(() => _unreadCount = next.unreadCount);
      }
      if (previous != null && next.revision > previous.revision) {
        _load();
      }
    });

    return ParentPageScaffold(
      title: 'Thông báo',
      leading: buildAppBackLeading(
        context,
        fallbackRoute: '/parent/dashboard',
      ),
      actions: [
        if (_unreadCount > 0)
          TextButton(onPressed: _markAllRead, child: const Text('Đọc tất cả')),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('ALL', 'Tất cả'),
                  ('UNREAD', 'Chưa đọc'),
                  ('ACTIVITY', 'Hoạt động'),
                  ('SAFETY', 'An toàn'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: _filter == entry.$1,
                    showCheckmark: false,
                    selectedColor: AppTheme.primarySoft,
                    labelStyle: TextStyle(
                      color: _filter == entry.$1
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _filter == entry.$1
                          ? AppTheme.primary
                          : AppTheme.neutral200,
                    ),
                    onSelected: (_) {
                      setState(() => _filter = entry.$1);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          ParentEmptyState(
            icon: Iconsax.warning_2,
            title: 'Không tải được thông báo',
            description: _error!,
            actionLabel: 'Thử lại',
            onAction: _load,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 48),
          ParentEmptyState(
            icon: Iconsax.notification,
            title: 'Chưa có thông báo',
            description:
                'Cập nhật an toàn, điểm danh và hoạt động tour sẽ hiện tại đây.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final when = item.createdAt == null
            ? null
            : DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt!.toLocal());
        return ParentListTileCard(
          key: ValueKey(item.recipientId),
          unread: !item.read,
          title: item.title,
          subtitle: when == null ? item.body : '${item.body}\n$when',
          leading: ParentIconWell(
            icon: Iconsax.notification,
            backgroundColor: item.read
                ? AppTheme.neutral100
                : AppTheme.primarySoft,
            iconColor: item.read ? AppTheme.onSurfaceVariant : AppTheme.primary,
          ),
          trailing: item.read
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.cta,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () => _openItem(item),
        );
      },
    );
  }
}
