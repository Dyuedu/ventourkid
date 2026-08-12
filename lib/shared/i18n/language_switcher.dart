import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'app_language.dart';
import 'app_localizations.dart';

enum LanguageSwitcherTone {
  /// White / light canvas (default AppBar).
  surface,

  /// Blue / dark chrome (auth top bar).
  onPrimary,
}

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({
    super.key,
    this.compact = true,
    this.tone = LanguageSwitcherTone.surface,
    this.onChanged,
  });

  final bool compact;
  final LanguageSwitcherTone tone;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageControllerProvider);
    final onPrimary = tone == LanguageSwitcherTone.onPrimary;
    final textTheme = Theme.of(context).textTheme;

    return PopupMenuButton<String>(
      tooltip: ref.tr('Chọn ngôn ngữ'),
      offset: const Offset(0, 10),
      position: PopupMenuPosition.under,
      elevation: 10,
      shadowColor: AppTheme.ink.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      color: AppTheme.surface,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 196, maxWidth: 228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.neutral200),
      ),
      onSelected: (code) async {
        await ref
            .read(appLanguageControllerProvider.notifier)
            .setLanguage(code);
        onChanged?.call();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < appLanguages.length; i++)
          PopupMenuItem<String>(
            value: appLanguages[i].code,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _LanguageMenuRow(
              language: appLanguages[i],
              selected: appLanguages[i].code == language.code,
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        height: compact ? 36 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: onPrimary
              ? Colors.white.withValues(alpha: 0.16)
              : AppTheme.primarySoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: onPrimary
                ? Colors.white.withValues(alpha: 0.28)
                : AppTheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 18,
              color: onPrimary ? Colors.white : AppTheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              language.shortLabel,
              style: textTheme.labelMedium?.copyWith(
                color: onPrimary ? Colors.white : AppTheme.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: onPrimary
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppTheme.neutral700,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageMenuRow extends StatelessWidget {
  const _LanguageMenuRow({
    required this.language,
    required this.selected,
  });

  final AppLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: AppTheme.motionFast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : AppTheme.neutral100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              language.shortLabel,
              style: textTheme.labelSmall?.copyWith(
                color: selected ? AppTheme.primary : AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              language.label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppTheme.primary,
            ),
        ],
      ),
    );
  }
}
