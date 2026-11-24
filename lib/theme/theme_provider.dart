import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'theme_presets.dart';

/// Holds the chosen theme (light/dark/system, color preset, custom color)
/// and remembers it between app launches.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  String _presetId = ThemePresets.defaultId;
  Color? _customAccent;

  ThemeMode get mode => _mode;
  String get presetId => _presetId;
  Color? get customAccent => _customAccent;

  /// True when the user picked their own color instead of a preset.
  bool get isCustom => _presetId == ThemePresets.customId && _customAccent != null;

  /// The active theme (preset or custom).
  ThemePreset get preset {
    if (isCustom) return ThemePresets.fromAccent(_customAccent!);
    return ThemePresets.byId(_presetId);
  }

  Color get accent => preset.accent;
  List<Color> get auroraColors => preset.aurora;

  // ---------- Load / save ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeName = prefs.getString(AppConstants.keyThemeMode);
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.dark,
      );

      _presetId = prefs.getString(AppConstants.keyPresetId) ?? ThemePresets.defaultId;

      final customValue = prefs.getInt(AppConstants.keyCustomAccent);
      if (customValue != null) {
        _customAccent = Color(customValue);
      }
      if (_presetId == ThemePresets.customId && _customAccent == null) {
        _presetId = ThemePresets.defaultId;
      }
    } catch (_) {
      // If saved settings cannot be read, just use the defaults.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyThemeMode, _mode.name);
      await prefs.setString(AppConstants.keyPresetId, _presetId);
      if (_customAccent != null) {
        await prefs.setInt(AppConstants.keyCustomAccent, _customAccent!.toARGB32());
      }
    } catch (_) {
      // Saving is best-effort.
    }
  }

  // ---------- Changes ----------

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setPreset(String id) async {
    _presetId = id;
    notifyListeners();
    await _save();
  }

  /// Uses any color the user picks as the accent for the whole app.
  Future<void> setCustomAccent(Color color) async {
    _customAccent = color;
    _presetId = ThemePresets.customId;
    notifyListeners();
    await _save();
  }
}
