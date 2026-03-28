import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design tokens for FlatOrg.
///
/// All colours, font sizes and theme objects are defined here and imported
/// wherever a visual value is needed — no magic numbers in widget code.
class AppTheme {
  AppTheme._();

  // ── Background colours ────────────────────────────────────────────────────

  /// Page/scaffold background — light mode.
  static const Color bgLight = Color(0xFFEEEEEE);

  /// Page/scaffold background — dark mode.
  static const Color bgDark = Color(0xFF262626);

  // ── Brand palette ─────────────────────────────────────────────────────────

  /// Muted sage green — buttons, navigation highlights, primary actions.
  static const Color featureColor = Color(0xFFACBFA4);

  /// Light sage — card surfaces, input backgrounds, secondary highlights.
  static const Color accentColor = Color(0xFFE2E8CE);

  // ── Task-state colours (ONLY for the 4 px top bar on task cards) ──────────

  static const Color stateCompleted = Color(0xFF10B981); // green
  static const Color statePending   = Color(0xFFF59E0B); // amber
  static const Color stateNotDone   = Color(0xFFEF4444); // red
  static const Color stateVacant    = Color(0xFF3B82F6); // blue

  // ── Destructive colour (remove member, irreversible confirm dialogs) ───────

  static const Color destructiveRed = Color(0xFF991B1B);

  // ── Greyscale (3 shades) ──────────────────────────────────────────────────

  /// Subtle dividers and disabled backgrounds.
  static const Color grayLight = Color(0xFFD1D5DB);

  /// Secondary / hint text.
  static const Color grayMid = Color(0xFF6B7280);

  /// Primary body text (light mode).
  static const Color grayDark = Color(0xFF374151);

  // ── Font sizes (3 centralised values) ────────────────────────────────────

  static const double fontSmall  = 12.0;
  static const double fontMedium = 16.0;
  static const double fontLarge  = 24.0;

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Border radius ─────────────────────────────────────────────────────────

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // ── Task-state colour bar height ──────────────────────────────────────────

  static const double taskStateBarHeight = 4.0;

  // ── Public Sans text theme ────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color bodyColor, Color displayColor) {
    return GoogleFonts.publicSansTextTheme(
      TextTheme(
        displayLarge:  TextStyle(fontSize: fontLarge,  fontWeight: FontWeight.w700, color: displayColor),
        titleLarge:    TextStyle(fontSize: fontLarge,  fontWeight: FontWeight.w600, color: displayColor),
        titleMedium:   TextStyle(fontSize: fontMedium, fontWeight: FontWeight.w600, color: displayColor),
        bodyLarge:     TextStyle(fontSize: fontMedium, fontWeight: FontWeight.w400, color: bodyColor),
        bodyMedium:    TextStyle(fontSize: fontMedium, fontWeight: FontWeight.w400, color: bodyColor),
        bodySmall:     TextStyle(fontSize: fontSmall,  fontWeight: FontWeight.w400, color: bodyColor),
        labelSmall:    TextStyle(fontSize: fontSmall,  fontWeight: FontWeight.w500, color: bodyColor),
        labelMedium:   TextStyle(fontSize: fontSmall,  fontWeight: FontWeight.w500, color: bodyColor),
        labelLarge:    TextStyle(fontSize: fontMedium, fontWeight: FontWeight.w500, color: bodyColor),
      ),
    );
  }

  // ── Light theme ───────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(grayDark, grayDark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: featureColor,
        secondary: accentColor,
        surface: bgLight,
        onPrimary: Color(0xFF374151),
        onSecondary: Color(0xFF374151),
        onSurface: Color(0xFF374151),
        error: stateNotDone,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgLight,
        foregroundColor: grayDark,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: grayMid),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grayLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grayLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: featureColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + spacingXs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: featureColor,
          foregroundColor: grayDark,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingSm + spacingXs,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: grayDark,
          side: const BorderSide(color: grayLight),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingSm + spacingXs,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: grayLight, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgLight,
        selectedItemColor: featureColor,
        unselectedItemColor: grayMid,
        elevation: 8,
      ),
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(accentColor, accentColor);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: featureColor,
        secondary: accentColor,
        surface: Color(0xFF333333),
        onPrimary: Color(0xFF262626),
        onSecondary: Color(0xFF262626),
        onSurface: accentColor,
        error: stateNotDone,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: accentColor,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF333333),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF333333),
        hintStyle: const TextStyle(color: grayMid),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grayMid),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grayMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: featureColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + spacingXs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: featureColor,
          foregroundColor: bgDark,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingSm + spacingXs,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: grayMid),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingSm + spacingXs,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: grayMid, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgDark,
        selectedItemColor: featureColor,
        unselectedItemColor: grayMid,
        elevation: 8,
      ),
    );
  }
}
