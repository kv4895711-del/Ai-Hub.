import 'package:flutter/material.dart';

/// Orbit's black-and-white look. Everything is a shade of black, grey or white.
/// The only color is the gateway's green/red status dot and error messages.
class AppTheme {
  AppTheme._();

  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _paper = Color(0xFFF5F5F5);

  // ---------- Main colors ----------

  /// The "ink" color: near-white on dark, near-black on light.
  static Color accentFor(bool isDark) => isDark ? _paper : _ink;

  /// Text or icons placed ON the ink color (for example inside a send button).
  static Color onAccentFor(bool isDark) => isDark ? _ink : _paper;

  static Color baseBackground(bool isDark) {
    return isDark ? const Color(0xFF050505) : const Color(0xFFFAFAFA);
  }

  /// Cards and sheets that sit on the background.
  static Color surface(bool isDark) {
    return isDark ? const Color(0xFF111111) : const Color(0xFFF0F0F0);
  }

  /// A step lighter than [surface] (other person's chat bubble, pop-ups).
  static Color surfaceHigh(bool isDark) {
    return isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE6E6E8);
  }

  static Color textPrimary(bool isDark) {
    return isDark ? _paper : _ink;
  }

  static Color textSecondary(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.55);
  }

  // ---------- Glass (kept for older widgets, now flat and quiet) ----------

  /// Soft fill for cards. [strength] 1.0 is normal, higher is more solid.
  static Color glassFill(bool isDark, {double strength = 1.0}) {
    final base = isDark ? 0.07 : 0.045;
    final alpha = (base * strength).clamp(0.0, 1.0);
    return (isDark ? Colors.white : Colors.black).withValues(alpha: alpha);
  }

  /// Thin line around cards.
  static Color glassBorder(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
  }

  /// Shadows are barely needed on black, a little on white.
  static Color glassShadow(bool isDark) {
    return Colors.black.withValues(alpha: isDark ? 0.0 : 0.06);
  }

  // ---------- Theme builder ----------

  /// [accent] is ignored on purpose (kept so older code still compiles):
  /// the colors always come from [brightness].
  static ThemeData build({
    required Brightness brightness,
    Color? accent,
  }) {
    final isDark = brightness == Brightness.dark;
    final ink = accentFor(isDark);
    final onInk = onAccentFor(isDark);
    final primaryText = textPrimary(isDark);
    final secondaryText = textSecondary(isDark);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: onInk,
      secondary: ink,
      onSecondary: onInk,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: surface(isDark),
      onSurface: primaryText,
    );

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
      dividerColor: glassBorder(isDark),
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
        backgroundColor: isDark ? const Color(0xFF262628) : const Color(0xFF1A1A1C),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? onInk : secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? ink
              : secondaryText.withValues(alpha: 0.25);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ink,
        inactiveTrackColor: secondaryText.withValues(alpha: 0.25),
        thumbColor: ink,
        overlayColor: ink.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: 0.28),
        selectionHandleColor: ink,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryText,
        textColor: primaryText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
