import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'brand_logo.dart';

/// Branded cold-start screen. Keep a stable [Key] at the call site so the
/// progress animation and logo are not remounted (avoids flicker).
class AppBootstrapSplash extends StatefulWidget {
  const AppBootstrapSplash({
    super.key,
    this.message = 'Đang mở hành trình của bạn…',
  });

  final String message;

  static const skyTop = Color(0xFFDBEAFE);
  static const skyMid = Color(0xFFBFDBFE);
  static const sea = Color(0xFF7DD3FC);
  static const inkSoft = Color(0xFF1E3A5F);

  @override
  State<AppBootstrapSplash> createState() => _AppBootstrapSplashState();
}

class _AppBootstrapSplashState extends State<AppBootstrapSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppBootstrapSplash.skyTop,
                AppBootstrapSplash.skyMid,
                Color(0xFFE0F2FE),
                AppBootstrapSplash.sea,
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    // Square box + contain keeps 1:1; ClipOval only masks corners.
                    child: const ClipOval(
                      child: BrandLogo(size: 204),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'An toàn trên mọi hành trình',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppBootstrapSplash.inkSoft.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(flex: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 4,
                      child: AnimatedBuilder(
                        animation: _bar,
                        builder: (context, _) {
                          // Smooth indeterminate bar without remounting
                          // Material LinearProgressIndicator on rebuilds.
                          final t = Curves.easeInOut.transform(_bar.value);
                          final start = (t * 1.35) - 0.35;
                          final end = start + 0.35;
                          return CustomPaint(
                            painter: _BarPainter(
                              start: start.clamp(0.0, 1.0),
                              end: end.clamp(0.0, 1.0),
                              track: Colors.white.withValues(alpha: 0.45),
                              fill: AppTheme.primary,
                            ),
                            size: const Size(double.infinity, 4),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppBootstrapSplash.inkSoft.withValues(
                            alpha: 0.75,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.start,
    required this.end,
    required this.track,
    required this.fill,
  });

  final double start;
  final double end;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.fill;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      trackPaint,
    );
    if (end <= start) return;
    final left = size.width * start;
    final right = size.width * end;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, 0, right, size.height),
        radius,
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}

/// Lightweight placeholder matching splash colors — no logo remount flicker.
class AppBootstrapHold extends StatelessWidget {
  const AppBootstrapHold({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppBootstrapSplash.skyTop,
      child: SizedBox.expand(),
    );
  }
}
