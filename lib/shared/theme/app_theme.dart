import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VentourKid design tokens — parent tracking context (ui-ux-pro-max).
/// Primary blue #2563EB + CTA orange #F97316 + Lexend / Plus Jakarta Sans.
class AppTheme {
  // ——— Brand ———
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primarySoft = Color(0xFFDBEAFE);
  static const cta = Color(0xFFF97316);
  static const canvas = Color(0xFFEFF6FF);
  static const ink = Color(0xFF1E3A5F);

  // ——— Neutrals ———
  static const neutral950 = Color(0xFF0F172A);
  static const neutral900 = Color(0xFF171717);
  static const neutral700 = Color(0xFF334155);
  static const neutral500 = Color(0xFF64748B);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral100 = Color(0xFFF1F5F9);

  // ——— Semantic aliases ———
  static const navy = ink;
  static const secondary = primary;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLight = canvas;
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF8FAFC);
  static const surfaceContainer = primarySoft;
  static const surfaceContainerHigh = Color(0xFFBFDBFE);
  static const surfaceVariant = neutral200;
  static const secondaryContainer = primarySoft;
  static const errorContainer = Color(0xFFFEE2E2);
  static const outline = neutral500;
  static const outlineVariant = neutral200;
  static const onSurface = ink;
  static const onSurfaceVariant = Color(0xFF475569);
  static const onPrimaryContainer = primary;
  static const accentGreen = Color(0xFF059669);
  static const accentOrange = cta;
  static const accentRed = Color(0xFFDC2626);
  static const warmMediaAccent = Color(0x4DF97316);

  // ——— Spacing ———
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 16.0;
  static const spaceLg = 24.0;
  static const spaceXl = 32.0;
  static const space2xl = 48.0;

  // ——— Radii ———
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radiusPill = 999.0;

  // ——— Motion ———
  static const motionFast = Duration(milliseconds: 150);
  static const motionNormal = Duration(milliseconds: 220);
  static const motionSlow = Duration(milliseconds: 300);

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: ink.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: ink.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: ink.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static TextTheme _buildTextTheme(TextTheme base, {required Color color}) {
    final body = GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
    final display = GoogleFonts.lexendTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );

    // Always pin `color` — Google Fonts styles can drop inherited colors and
    // leave near-invisible text on light canvases (surfaceLight / white cards).
    TextStyle? pin(TextStyle? style, {FontWeight? weight}) => style?.copyWith(
          color: color,
          fontWeight: weight ?? style.fontWeight,
        );

    return body.copyWith(
      displayLarge: pin(display.displayLarge, weight: FontWeight.w700),
      displayMedium: pin(display.displayMedium, weight: FontWeight.w700),
      displaySmall: pin(display.displaySmall, weight: FontWeight.w700),
      headlineLarge: pin(display.headlineLarge, weight: FontWeight.w700),
      headlineMedium: pin(display.headlineMedium, weight: FontWeight.w700),
      headlineSmall: pin(display.headlineSmall, weight: FontWeight.w700),
      titleLarge: pin(display.titleLarge, weight: FontWeight.w700),
      titleMedium: pin(body.titleMedium, weight: FontWeight.w700),
      titleSmall: pin(body.titleSmall, weight: FontWeight.w700),
      bodyLarge: pin(body.bodyLarge),
      bodyMedium: pin(body.bodyMedium),
      bodySmall: pin(body.bodySmall),
      labelLarge: pin(body.labelLarge, weight: FontWeight.w700),
      labelMedium: pin(body.labelMedium, weight: FontWeight.w700),
      labelSmall: pin(body.labelSmall, weight: FontWeight.w700),
    );
  }

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: cta,
      onSecondary: Colors.white,
      tertiary: primaryLight,
      onTertiary: Colors.white,
      error: accentRed,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHighest: surfaceContainer,
      outline: outline,
      outlineVariant: outlineVariant,
    );
    final textTheme = _buildTextTheme(ThemeData.light().textTheme, color: ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: surfaceLight,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: ink.withValues(alpha: 0.08),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: neutral200),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: neutral200,
          disabledForegroundColor: neutral500,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentRed, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        floatingLabelStyle:
            textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(color: neutral500),
        prefixIconColor: neutral700,
        suffixIconColor: neutral700,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primarySoft,
        selectedColor: primary,
        labelStyle: textTheme.labelMedium?.copyWith(color: ink),
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primarySoft,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? primary : onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: primarySoft,
      ),
      dividerTheme: const DividerThemeData(
        color: neutral200,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cta,
        foregroundColor: Colors.white,
      ),
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: primary,
        headerForegroundColor: Colors.white,
        todayForegroundColor: const WidgetStatePropertyAll(primary),
        todayBackgroundColor: WidgetStatePropertyAll(primarySoft),
      ),
    );
  }

  static ThemeData get dark {
    final textTheme = _buildTextTheme(
      ThemeData.dark().textTheme,
      color: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primaryLight),
    );
  }
}
