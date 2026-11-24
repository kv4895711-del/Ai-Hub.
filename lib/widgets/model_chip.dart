import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/models_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// A small pill that shows the model chosen right now, for example "Auto" or
/// "gemini-2.5-flash". Tapping it calls [onTap] (the chat screen opens the
/// model list). While the list is loading, a tiny spinner is shown.
class ModelChip extends StatelessWidget {
  const ModelChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.watch<ThemeProvider>().accent;
    final models = context.watch<ModelsProvider>();
    final haptics = context.read<SettingsProvider>().haptics;

    final name = models.selectedName;
    final hasError = models.error != null && !models.isLoading;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppUtils.selectionHaptic(haptics);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(maxWidth: 170),
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: accent.withValues(alpha: 0.14),
          border: Border.all(color: accent.withValues(alpha: 0.40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (models.isLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              )
            else
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.auto_awesome_rounded,
                size: 14,
                color: hasError ? const Color(0xFFF59E0B) : accent,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  name,
                  key: ValueKey<String>(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: AppTheme.textSecondary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
