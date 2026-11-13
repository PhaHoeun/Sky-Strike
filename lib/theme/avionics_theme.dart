import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Core color tokens for the Apex Avionics HUD military sci-fi aesthetic.
abstract final class AvionicsColors {
  static const Color surface = Color(0xFF0C1320);
  static const Color surfaceLowest = Color(0xFF070E1B);
  static const Color surfaceLow = Color(0xFF151C29);
  static const Color surfaceContainer = Color(0xFF19202D);
  static const Color surfaceHigh = Color(0xFF232A38);
  static const Color surfaceHighest = Color(0xFF2E3543);

  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanFixed = Color(0xFF9CF0FF);
  static const Color cyanDim = Color(0xFF00DAF3);

  static const Color orange = Color(0xFFFE6B00);
  static const Color orangeDark = Color(0xFFD94A00);
  static const Color orangePeach = Color(0xFFFFB693);

  static const Color emerald = Color(0xFF00E676);
  static const Color emeraldBright = Color(0xFF22EF7E);
  static const Color emeraldDeep = Color(0xFF003919);

  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFE082);
  static const Color crimson = Color(0xFFFF4D4D);

  static const Color onSurface = Color(0xFFDCE2F5);
  static const Color onSurfaceVariant = Color(0xFFBAC9CC);
  static const Color outline = Color(0xFF849396);
  static const Color outlineVariant = Color(0xFF3B494C);
}

/// Typography helpers pairing Space Grotesk headers with JetBrains Mono telemetry.
abstract final class AvionicsText {
  /// Allows unit/widget tests without bundled font assets to use clean fallbacks.
  static bool useGoogleFonts = true;

  static TextStyle headline({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AvionicsColors.onSurface,
    double letterSpacing = 1.1,
    double? height,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AvionicsColors.onSurfaceVariant,
    double letterSpacing = 1.0,
    double? height,
    bool tabular = true,
  }) {
    final features = tabular ? const [FontFeature.tabularFigures()] : null;
    if (!useGoogleFonts) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: features,
      );
    }
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: features,
    );
  }
}

/// Theme configuration for the Sky Strike Flutter application.
abstract final class AvionicsTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AvionicsColors.surface,
      canvasColor: AvionicsColors.surfaceLowest,
      colorScheme: const ColorScheme.dark(
        primary: AvionicsColors.cyan,
        onPrimary: AvionicsColors.surfaceLowest,
        secondary: AvionicsColors.orange,
        onSecondary: AvionicsColors.surfaceLowest,
        tertiary: AvionicsColors.emerald,
        surface: AvionicsColors.surface,
        onSurface: AvionicsColors.onSurface,
        surfaceContainerHighest: AvionicsColors.surfaceHighest,
        outline: AvionicsColors.outline,
        outlineVariant: AvionicsColors.outlineVariant,
        error: AvionicsColors.crimson,
      ),
      textTheme: base.textTheme.apply(
        fontFamily:
            AvionicsText.useGoogleFonts ? GoogleFonts.spaceGrotesk().fontFamily : null,
        bodyColor: AvionicsColors.onSurface,
        displayColor: AvionicsColors.onSurface,
      ),
      dividerColor: AvionicsColors.outlineVariant.withValues(alpha: 0.35),
      dialogTheme: const DialogThemeData(
        backgroundColor: AvionicsColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
