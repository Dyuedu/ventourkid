import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../theme/app_theme.dart';

/// Shared parent chrome — vibrant block-based layout for VentourKid parents.
class ParentPageScaffold extends StatelessWidget {
  const ParentPageScaffold({
    required this.title,
    required this.body,
    super.key,
    this.leading,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      drawer: drawer,
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: body,
    );
  }
}

class ParentSectionHeader extends StatelessWidget {
  const ParentSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class ParentCard extends StatelessWidget {
  const ParentCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
    this.emphasized = false,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    final decoration = BoxDecoration(
      color: color ?? AppTheme.surface,
      borderRadius: radius,
      border: Border.all(
        color: emphasized
            ? AppTheme.primary.withValues(alpha: 0.35)
            : AppTheme.neutral200,
        width: emphasized ? 2 : 1,
      ),
      boxShadow: emphasized ? AppTheme.shadowMd : AppTheme.shadowSm,
    );

    if (onTap == null) {
      return Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ParentIconWell extends StatelessWidget {
  const ParentIconWell({
    required this.icon,
    super.key,
    this.size = 44,
    this.iconSize = 22,
    this.backgroundColor = AppTheme.primarySoft,
    this.iconColor = AppTheme.primary,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

class ParentStatusChip extends StatelessWidget {
  const ParentStatusChip({
    required this.label,
    super.key,
    this.color = AppTheme.accentGreen,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
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

class ParentBanner extends StatelessWidget {
  const ParentBanner({
    required this.text,
    super.key,
    this.icon = Iconsax.info_circle,
    this.tone = ParentBannerTone.info,
  });

  final String text;
  final IconData icon;
  final ParentBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ParentBannerTone.info => (AppTheme.primarySoft, AppTheme.primary),
      ParentBannerTone.success => (
          const Color(0xFFD1FAE5),
          AppTheme.accentGreen,
        ),
      ParentBannerTone.warning => (
          const Color(0xFFFFEDD5),
          AppTheme.accentOrange,
        ),
      ParentBannerTone.danger => (AppTheme.errorContainer, AppTheme.accentRed),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurface,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ParentBannerTone { info, success, warning, danger }

class ParentEmptyState extends StatelessWidget {
  const ParentEmptyState({
    required this.title,
    required this.description,
    super.key,
    this.icon = Iconsax.box,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Column(
        children: [
          ParentIconWell(icon: icon, size: 56, iconSize: 28),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ParentListTileCard extends StatelessWidget {
  const ParentListTileCard({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.unread = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: unread ? AppTheme.primarySoft.withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
