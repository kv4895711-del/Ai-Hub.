import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_presets.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';

/// Pick a ready-made color theme or build your own from any color.
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context, isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                  children: [
                    _buildPreview(isDark, theme),
                    const SizedBox(height: 22),
                    _sectionTitle(isDark, 'Ready-made themes'),
                    _buildPresetGrid(context, isDark, theme),
                    const SizedBox(height: 22),
                    _sectionTitle(isDark, 'Your own color'),
                    _buildCustomCard(context, isDark, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Top bar ----------

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: GlassCard(
              radius: 22,
              padding: EdgeInsets.zero,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Color theme',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _sectionTitle(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary(isDark),
        ),
      ),
    );
  }

  // ---------- Live preview ----------

  Widget _buildPreview(bool isDark, ThemeProvider theme) {
    final colors = theme.auroraColors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withValues(alpha: 0.85),
            colors[1].withValues(alpha: 0.75),
            colors[2].withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'How can I help?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: const Text(
                'Looks great!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Ready-made themes ----------

  Widget _buildPresetGrid(BuildContext context, bool isDark, ThemeProvider theme) {
    final presets = ThemePresets.all;
    final haptics = context.read<SettingsProvider>().haptics;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: presets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, i) {
        final preset = presets[i];
        final selected = !theme.isCustom && theme.presetId == preset.id;
        return _PresetTile(
          preset: preset,
          selected: selected,
          isDark: isDark,
          onTap: () {
            AppUtils.selectionHaptic(haptics);
            theme.setPreset(preset.id);
          },
        );
      },
    );
  }

  // ---------- Custom color ----------

  Widget _buildCustomCard(BuildContext context, bool isDark, ThemeProvider theme) {
    final custom = theme.customAccent;
    final selected = theme.isCustom;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: custom ?? Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? theme.accent
                        : AppTheme.glassBorder(isDark),
                    width: selected ? 3 : 1.5,
                  ),
                ),
                child: custom == null
                    ? Icon(
                        Icons.palette_outlined,
                        color: AppTheme.textSecondary(isDark),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custom == null ? 'No custom color yet' : 'Custom color',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick any color. The whole app and the background '
                      'will match it.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppTheme.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openPicker(context, theme),
              style: FilledButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.colorize_rounded, size: 20),
              label: Text(custom == null ? 'Choose a color' : 'Change color'),
            ),
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context, ThemeProvider theme) {
    Color picked = theme.customAccent ?? theme.accent;
    final haptics = context.read<SettingsProvider>().haptics;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
          child: GlassCard(
            radius: 28,
            strength: 2.2,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Make your own theme',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ColorPicker(
                        pickerColor: picked,
                        onColorChanged: (c) => setSheetState(() => picked = c),
                        enableAlpha: false,
                        hexInputBar: true,
                        labelTypes: const [],
                        pickerAreaHeightPercent: 0.7,
                        portraitOnly: true,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary(isDark),
                                side: BorderSide(
                                  color: AppTheme.glassBorder(isDark),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                AppUtils.mediumHaptic(haptics);
                                theme.setCustomAccent(picked);
                                Navigator.of(sheetContext).pop();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: picked,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Use this color'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One ready-made theme: a small gradient card with its name.
class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = preset.aurora;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors[0].withValues(alpha: 0.9),
              colors[1].withValues(alpha: 0.8),
              colors[2].withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: preset.accent.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                preset.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  shadows: [
                    Shadow(color: Color(0x66000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: preset.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
