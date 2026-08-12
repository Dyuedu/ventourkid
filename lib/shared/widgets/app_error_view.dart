import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_theme.dart';

class AppErrorView extends ConsumerWidget {
  const AppErrorView({
    super.key,
    this.message = 'Đã xảy ra lỗi. Vui lòng thử lại.',
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final translatedMessage = ref.tr(message);
    final translatedRetryLabel = ref.tr(retryLabel);

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
                color: AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.accentRed,
                size: 36,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              translatedMessage,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurface,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(translatedRetryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}