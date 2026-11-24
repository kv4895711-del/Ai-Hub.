import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// Three bouncing dots, shown while the AI has not started writing yet.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.watch<ThemeProvider>().accent;
    final idle = AppTheme.textSecondary(isDark);

    return SizedBox(
      height: 26,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) _dot(i, accent, idle),
            ],
          );
        },
      ),
    );
  }

  Widget _dot(int index, Color accent, Color idle) {
    // Each dot is a little behind the one before it.
    final phase = (_controller.value - index * 0.16) % 1.0;
    final wave = math.sin(phase * math.pi * 2);
    final lift = wave > 0 ? wave : 0.0; // only the upward half bounces

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Transform.translate(
        offset: Offset(0, -7 * lift),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(idle, accent, lift),
          ),
        ),
      ),
    );
  }
}
