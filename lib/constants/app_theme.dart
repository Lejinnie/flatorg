import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design tokens for FlatOrg.
///
/// All colours, font sizes and theme objects are defined here and imported
/// wherever a visual value is needed — no magic numbers in widget code.
class AppTheme {
  AppTheme._();

  // ── Background colours ────────────────────────────────────────────────────

  /// Page/scaffold background — light mode. hsl(108, 50%, 90%)
  static const bgLight = Color(0xFFDEF2D9);

  /// Page/scaffold background — dark mode. hsl(108, 50%, 10%)
  static const bgDark = Color(0xFF12260D);

  /// Bottom-sheet / floating-surface background — soft mint.
  static const bgMintSoft = Color(0xFFEDF6E2);

  // ── Brand palette ─────────────────────────────────────────────────────────

  /// Dark card background in dark mode — slightly lighter than [bgDark].
  static const cardColorDark = Color(0xFF1C3815);

  /// Interactive / feature colour — light mode. hsl(168, 80%, 20%)
  static const featureColor = Color(0xFF0A5C4B);

  /// Interactive / feature colour — dark mode. hsl(168, 80%, 80%)
  static const featureColorDark = Color(0xFFA3F5E4);

  /// Selected-card background in dark mode — same hue as [featureColorDark].
  static const selectionColor = Color(0xFF3BBEA8);

  /// Accent / highlight colour — light mode. hsl(48, 80%, 20%)
  static const highlightColor = Color(0xFF5C4B0A);

  /// Accent / highlight colour — dark mode. hsl(48, 80%, 80%)
  static const highlightColorDark = Color(0xFFF5E4A3);

  // ── Task-state colours (ONLY for the 4 px top bar on task cards) ──────────

  static const stateCompleted = Color(0xFF10B981); // green
  static const statePending = Color(0xFFF59E0B); // amber
  static const stateNotDone = Color(0xFFEF4444); // red
  static const stateVacant = Color(0xFF3B82F6); // blue

  // ── Destructive colour (remove member, irreversible confirm dialogs) ───────

  static const destructiveRed = Color(0xFF991B1B);

  // ── Greyscale (3 shades) ──────────────────────────────────────────────────

  /// Subtle dividers and disabled backgrounds.
  static const grayLight = Color(0xFFD1D5DB);

  /// Secondary / hint text.
  static const grayMid = Color(0xFF6B7280);

  /// Unit labels and non-critical annotations — lighter than grayMid.
  static const secondaryTextColor = Color(0xFF9CA3AF);

  /// Primary body text (light mode). hsl(108, 50%, 10%) — matches [bgDark].
  static const grayDark = Color(0xFF12260D);

  // ── Font sizes (3 centralised values) ────────────────────────────────────

  static const fontSmall = 12.0;
  static const fontMedium = 16.0;
  static const fontLarge = 24.0;

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;

  // ── Border radius ─────────────────────────────────────────────────────────

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;

  // ── Task-state colour bar height ──────────────────────────────────────────

  static const taskStateBarHeight = 6.0;

  // ── Public Sans text theme ────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color bodyColor, Color displayColor) =>
      GoogleFonts.publicSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(
              fontSize: fontLarge,
              fontWeight: FontWeight.w700,
              color: displayColor),
          titleLarge: TextStyle(
              fontSize: fontLarge,
              fontWeight: FontWeight.w600,
              color: displayColor),
          titleMedium: TextStyle(
              fontSize: fontMedium,
              fontWeight: FontWeight.w600,
              color: displayColor),
          bodyLarge: TextStyle(
              fontSize: fontMedium,
              fontWeight: FontWeight.w400,
              color: bodyColor),
          bodyMedium: TextStyle(
              fontSize: fontMedium,
              fontWeight: FontWeight.w400,
              color: bodyColor),
          bodySmall: TextStyle(
              fontSize: fontSmall,
              fontWeight: FontWeight.w400,
              color: bodyColor),
          labelSmall: TextStyle(
              fontSize: fontSmall,
              fontWeight: FontWeight.w500,
              color: bodyColor),
          labelMedium: TextStyle(
              fontSize: fontSmall,
              fontWeight: FontWeight.w500,
              color: bodyColor),
          labelLarge: TextStyle(
              fontSize: fontMedium,
              fontWeight: FontWeight.w500,
              color: bodyColor),
        ),
      );

  // ── Light theme ───────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(grayDark, grayDark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: featureColor,
        secondary: highlightColor,
        surface: bgLight,
        // featureColor is dark teal → white text on primary buttons (Material default).
        onSurface: grayDark,
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
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
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
          // featureColor is dark teal — white text is readable.
          foregroundColor: Colors.white,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
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
    final textTheme = _buildTextTheme(Colors.white, Colors.white);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: featureColorDark,
        secondary: highlightColorDark,
        surface: bgDark,
        // featureColorDark is light teal → dark bg text is readable (Material default).
        onPrimary: bgDark,
        error: stateNotDone,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cardColorDark,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C3815),
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
          borderSide: const BorderSide(color: featureColorDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + spacingXs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: featureColorDark,
          // featureColorDark is light teal — dark bg text is readable.
          foregroundColor: bgDark,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
          foregroundColor: Colors.white,
          side: const BorderSide(color: grayMid),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
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
        selectedItemColor: featureColorDark,
        unselectedItemColor: grayMid,
        elevation: 8,
      ),
    );
  }
}
