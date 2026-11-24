import 'package:flutter/material.dart';

/// Builds the app's light and dark themes and holds the "glass" colors.
class AppTheme {
  AppTheme._();

  // ---------- Glass colors (used by GlassCard and other widgets) ----------

  /// Frosted-glass fill. [strength] 1.0 is normal, higher is more solid.
  static Color glassFill(bool isDark, {double strength = 1.0}) {
    final base = isDark ? 0.10 : 0.55;
    final alpha = (base * strength).clamp(0.0, 1.0);
    return (isDark ? Colors.white : Colors.white).withValues(alpha: alpha);
  }

  /// Thin border around glass surfaces.
  static Color glassBorder(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.70);
  }

  /// Soft shadow under glass surfaces.
  static Color glassShadow(bool isDark) {
    return Colors.black.withValues(alpha: isDark ? 0.35 : 0.10);
  }

  /// Solid color behind the aurora gradient.
  static Color baseBackground(bool isDark) {
    return isDark ? const Color(0xFF0A0B14) : const Color(0xFFF2F4FB);
  }

  static Color textPrimary(bool isDark) {
    return isDark ? const Color(0xFFF5F6FA) : const Color(0xFF14161F);
  }

  static Color textSecondary(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF14161F).withValues(alpha: 0.60);
  }

  // ---------- Theme builder ----------

  static ThemeData build({
    required Brightness brightness,
    required Color accent,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(primary: accent);

    final primaryText = textPrimary(isDark);
    final secondaryText = textSecondary(isDark);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: baseBackground(isDark),
      canvasColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: primaryText,
        displayColor: primaryText,
      ),
      iconTheme: IconThemeData(color: primaryText, size: 22),
      dividerColor: glassBorder(isDark).withValues(alpha: 0.5),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: primaryText,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF262838) : const Color(0xFF1E2030),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? Colors.white : secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? accent
              : secondaryText.withValues(alpha: 0.25);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: secondaryText.withValues(alpha: 0.25),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.15),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.30),
        selectionHandleColor: accent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryText,
        textColor: primaryText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
