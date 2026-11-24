import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Four tappable ideas shown on an empty chat. Tapping one sends it right away.
class ExamplePrompts extends StatelessWidget {
  const ExamplePrompts({super.key, required this.onSelected});

  final void Function(String prompt) onSelected;

  static const List<IconData> _icons = [
    Icons.lightbulb_outline_rounded,
    Icons.mail_outline_rounded,
    Icons.school_outlined,
    Icons.edit_note_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prompts = AppConstants.examplePrompts;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: [
          for (var i = 0; i < prompts.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              // Each card starts a little later than the one above it.
              duration: Duration(milliseconds: 450 + i * 120),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  onTap: () => onSelected(prompts[i]),
                  child: Row(
                    children: [
                      Icon(
                        _icons[i % _icons.length],
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          prompts[i],
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            color: AppTheme.textPrimary(isDark),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppTheme.textSecondary(isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
