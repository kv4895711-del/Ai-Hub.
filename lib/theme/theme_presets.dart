import 'package:flutter/material.dart';

/// One color theme: an accent color plus three colors for the aurora background.
class ThemePreset {
  final String id;
  final String name;
  final Color accent;
  final List<Color> aurora; // exactly 3 colors

  const ThemePreset({
    required this.id,
    required this.name,
    required this.accent,
    required this.aurora,
  });
}

/// All built-in color themes, plus a helper that makes one from any custom color.
class ThemePresets {
  ThemePresets._();

  static const String customId = 'custom';
  static const String defaultId = 'ocean';

  static const List<ThemePreset> all = [
    ThemePreset(
      id: 'ocean',
      name: 'Ocean',
      accent: Color(0xFF3B82F6),
      aurora: [Color(0xFF3B82F6), Color(0xFF06B6D4), Color(0xFF6366F1)],
    ),
    ThemePreset(
      id: 'violet',
      name: 'Violet Dream',
      accent: Color(0xFF8B5CF6),
      aurora: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF6366F1)],
    ),
    ThemePreset(
      id: 'sunset',
      name: 'Sunset',
      accent: Color(0xFFF97316),
      aurora: [Color(0xFFF97316), Color(0xFFEF4444), Color(0xFFFBBF24)],
    ),
    ThemePreset(
      id: 'emerald',
      name: 'Emerald',
      accent: Color(0xFF10B981),
      aurora: [Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF84CC16)],
    ),
    ThemePreset(
      id: 'rose',
      name: 'Rose',
      accent: Color(0xFFEC4899),
      aurora: [Color(0xFFEC4899), Color(0xFFF43F5E), Color(0xFFA855F7)],
    ),
    ThemePreset(
      id: 'teal',
      name: 'Aurora Teal',
      accent: Color(0xFF14B8A6),
      aurora: [Color(0xFF14B8A6), Color(0xFF22D3EE), Color(0xFF8B5CF6)],
    ),
    ThemePreset(
      id: 'midnight',
      name: 'Midnight',
      accent: Color(0xFF6366F1),
      aurora: [Color(0xFF312E81), Color(0xFF6366F1), Color(0xFF0EA5E9)],
    ),
    ThemePreset(
      id: 'gold',
      name: 'Gold',
      accent: Color(0xFFF59E0B),
      aurora: [Color(0xFFF59E0B), Color(0xFFFB7185), Color(0xFFFDE047)],
    ),
    ThemePreset(
      id: 'mint',
      name: 'Mint',
      accent: Color(0xFF2DD4BF),
      aurora: [Color(0xFF2DD4BF), Color(0xFF60A5FA), Color(0xFFA7F3D0)],
    ),
    ThemePreset(
      id: 'crimson',
      name: 'Crimson',
      accent: Color(0xFFE11D48),
      aurora: [Color(0xFFE11D48), Color(0xFF7C3AED), Color(0xFFFB923C)],
    ),
  ];

  /// Finds a preset by id. Falls back to the default one.
  static ThemePreset byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return all.first;
  }

  /// Builds a full theme from one custom accent color.
  static ThemePreset fromAccent(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    Color shift(double degrees) {
      final hue = (hsl.hue + degrees) % 360;
      return hsl.withHue(hue < 0 ? hue + 360 : hue).toColor();
    }

    return ThemePreset(
      id: customId,
      name: 'Custom',
      accent: accent,
      aurora: [accent, shift(40), shift(-40)],
    );
  }
}
