import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../data/models/livestream_setup_models.dart';

Future<ParentActiveLivestream?> showParentLivestreamPicker(
  BuildContext context,
  List<ParentActiveLivestream> sessions, {
  String? tourIdFilter,
}) {
  final filtered = tourIdFilter == null
      ? sessions
      : sessions.where((s) => s.tourId == tourIdFilter).toList();

  if (filtered.isEmpty) {
    return showDialog<ParentActiveLivestream>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa có livestream'),
        content: const Text(
          'Hiện không có phiên phát sóng nào bạn được phép xem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  if (filtered.length == 1) {
    return Future.value(filtered.first);
  }

  return showModalBottomSheet<ParentActiveLivestream>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chọn luồng phát sóng',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Có ${filtered.length} livestream đang diễn ra',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ...filtered.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ParentListTileCard(
                    title: session.title ?? session.tourName,
                    subtitle: session.subtitle,
                    leading: const ParentIconWell(
                      icon: Icons.live_tv,
                      backgroundColor: Color(0xFFFFEDD5),
                      iconColor: AppTheme.cta,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.primary,
                    ),
                    onTap: () => Navigator.pop(ctx, session),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
