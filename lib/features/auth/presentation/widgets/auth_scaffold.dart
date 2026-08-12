import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/i18n/language_switcher.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_bootstrap_splash.dart';
import '../../../../shared/widgets/brand_logo.dart';

class AuthViewport extends StatelessWidget {
  const AuthViewport({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: child,
      ),
    );
  }
}

/// Soft sky travel backdrop — matches splash, no dark stock photo.
class AuthSkyBackground extends StatelessWidget {
  const AuthSkyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppBootstrapSplash.skyTop,
                AppBootstrapSplash.skyMid,
                Color(0xFFE0F2FE),
                AppBootstrapSplash.sea,
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
          ),
        ),
        // Soft light blobs — atmosphere without clutter.
        Positioned(
          top: -48,
          right: -36,
          child: _GlowOrb(
            diameter: 180,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        Positioned(
          top: 120,
          left: -64,
          child: _GlowOrb(
            diameter: 160,
            color: AppTheme.primary.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          bottom: 80,
          right: -40,
          child: _GlowOrb(
            diameter: 200,
            color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          bottom: -20,
          left: 40,
          child: _GlowOrb(
            diameter: 120,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class AuthMediaScaffold extends StatelessWidget {
  const AuthMediaScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppBootstrapSplash.skyTop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuthSkyBackground(),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({required this.subtitle, super.key});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const ClipOval(
            child: BrandLogo(size: 108),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppBootstrapSplash.inkSoft.withValues(alpha: 0.78),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.subtitle, super.key});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppBootstrapSplash.skyTop,
            AppBootstrapSplash.skyMid,
            Color(0xFFE0F2FE),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AuthBrandHero(subtitle: subtitle),
      ),
    );
  }
}

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({required this.title, this.onBack, super.key});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                )
              else
                const SizedBox(width: 48),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VentourKid',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      title.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const LanguageSwitcher(tone: LanguageSwitcherTone.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class AuthVerificationCard extends StatelessWidget {
  const AuthVerificationCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.icon,
    super.key,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.helperText,
    this.helperColor,
    this.errorText,
    this.onChanged,
    this.textInputAction,
    this.inputFormatters,
    this.isRequired = false,
    this.lightOnGlass = false,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? helperText;
  final Color? helperColor;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool isRequired;
  final bool lightOnGlass;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorText != null;
    final labelColor = lightOnGlass
        ? Colors.white.withValues(alpha: 0.9)
        : AppTheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppTheme.accentRed),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            cursorColor: AppTheme.primary,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.neutral950,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: textTheme.bodyMedium?.copyWith(
                color: AppTheme.neutral500,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(icon, size: 20, color: AppTheme.neutral700),
              suffixIcon: suffix,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: hasError ? AppTheme.accentRed : AppTheme.neutral200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: hasError ? AppTheme.accentRed : AppTheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error, size: 16, color: AppTheme.accentRed),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                  ),
                ),
              ),
            ],
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: helperColor ?? AppTheme.accentGreen,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  helperText!,
                  style: textTheme.bodySmall?.copyWith(
                    color: helperColor ?? AppTheme.accentGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.filled = true,
    this.pill = false,
    this.isLoading = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool pill;
  final bool isLoading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800);
    final child = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          );

    if (filled) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cta,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              pill ? AppTheme.radiusPill : AppTheme.radiusMd,
            ),
          ),
          textStyle: textStyle,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: AppTheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            pill ? AppTheme.radiusPill : AppTheme.radiusMd,
          ),
        ),
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.label,
    required this.leading,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading || onPressed == null ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: AppTheme.neutral200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            leading,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.neutral200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.neutral500,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.neutral200)),
      ],
    );
  }
}

class TrustNote extends StatelessWidget {
  const TrustNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.security,
          size: 16,
          color: AppTheme.primary.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppBootstrapSplash.inkSoft.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class RequirementChip extends StatelessWidget {
  const RequirementChip({required this.label, required this.isMet, super.key});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppTheme.accentGreen : AppTheme.neutral500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class AuthStepper extends StatelessWidget {
  const AuthStepper({
    required this.currentStep,
    super.key,
    this.completedStepCount = 0,
  });

  final int currentStep;
  final int completedStepCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SafeArea(
        top: false,
        bottom: false,
        child: AuthViewport(
          child: Row(
            children: [
              _StepItem(
                index: 1,
                label: 'Tài khoản',
                isActive: currentStep == 1,
                isCompleted: completedStepCount >= 1,
              ),
              _StepLine(isCompleted: completedStepCount >= 1),
              _StepItem(
                index: 2,
                label: 'Xác minh',
                isActive: currentStep == 2,
                isCompleted: completedStepCount >= 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthOtpProgress extends StatelessWidget {
  const AuthOtpProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: AuthViewport(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _LargeStepItem(
                icon: Icons.check,
                label: 'Tài khoản',
                color: AppTheme.accentGreen,
                isIcon: true,
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 20),
                color: AppTheme.accentGreen,
              ),
            ),
            const Expanded(
              child: _LargeStepItem(
                label: 'Xác minh',
                color: AppTheme.primary,
                index: 2,
                isActive: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationIcon extends StatelessWidget {
  const VerificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppTheme.primarySoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.sms_outlined,
        color: AppTheme.primary,
        size: 32,
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? AppTheme.accentGreen
        : isActive
        ? AppTheme.primary
        : AppTheme.neutral500;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.accentGreen
                  : isActive
                  ? AppTheme.primary
                  : AppTheme.neutral200,
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isActive ? Colors.white : AppTheme.neutral500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeStepItem extends StatelessWidget {
  const _LargeStepItem({
    required this.label,
    required this.color,
    this.icon,
    this.index,
    this.isIcon = false,
    this.isActive = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final int? index;
  final bool isIcon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: isIcon
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  '${index ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isCompleted ? AppTheme.accentGreen : AppTheme.neutral200,
      ),
    );
  }
}
