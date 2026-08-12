import 'package:flutter/material.dart';

/// Shared VenTourKid / VeTourKid brand mark for splash, auth, and launcher assets.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 120,
    this.fit = BoxFit.contain,
  });

  static const assetPath = 'assets/branding/mobile_logo.png';

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Keep a strict square box; never stretch the PNG (logo is 1:1).
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.shield_outlined,
          size: size * 0.45,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
