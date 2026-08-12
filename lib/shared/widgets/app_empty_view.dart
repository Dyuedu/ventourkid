import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_theme.dart';

class AppEmptyView extends ConsumerWidget {
  const AppEmptyView({
    super.key,
    this.title = 'Chưa có dữ liệu',
    this.description = 'Dữ liệu sẽ hiển thị tại đây.',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final translatedTitle = ref.tr(title);
    final translatedDescription = ref.tr(description);
    final translatedActionLabel =
        actionLabel != null ? ref.tr(actionLabel!) : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              translatedTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              translatedDescription,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (translatedActionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              FilledButton(
                  onPressed: onAction, child: Text(translatedActionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}