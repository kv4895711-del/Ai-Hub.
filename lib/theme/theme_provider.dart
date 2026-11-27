import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'theme_presets.dart';

/// Orbit's look is black and white only. The user can choose Dark, Light or
/// System, and the choice is remembered between launches.
///
/// The old color-theme names (preset, customAccent, setPreset...) are kept so
/// the older screens still compile. They do nothing now and disappear when
/// those screens are replaced.
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  // ---------- Dark or light right now ----------

  /// True when the app is showing its dark look (also resolves "System").
  bool get isDark {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  /// The main "ink" color: near-white on dark, near-black on light.
  Color get accent =>
      isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A);

  /// Three greys used by the soft background glow.
  List<Color> get auroraColors => isDark
      ? const [Color(0xFF2B2B2B), Color(0xFF111111), Color(0xFF444444)]
      : const [Color(0xFFE6E6E6), Color(0xFFF8F8F8), Color(0xFFCFCFCF)];

  // ---------- Kept for older screens (they do nothing new) ----------

  String get presetId => 'mono';
  bool get isCustom => false;
  Color? get customAccent => null;

  ThemePreset get preset => ThemePreset(
        id: 'mono',
        name: 'Black & White',
        accent: accent,
        aurora: auroraColors,
      );

  Future<void> setPreset(String id) async {}

  Future<void> setCustomAccent(Color color) async {}

  // ---------- Follow the phone when "System" is chosen ----------

  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) notifyListeners();
  }

  // ---------- Load and save ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(AppConstants.keyThemeMode);
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.dark,
      );
    } catch (_) {
      // If the saved choice cannot be read, stay on Dark.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyThemeMode, mode.name);
    } catch (_) {
      // Saving is best-effort.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
