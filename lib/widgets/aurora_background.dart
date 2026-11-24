import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// A slowly moving aurora of soft colored glows, drawn behind a screen.
/// The colors come from the chosen theme. Put your screen inside [child].
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
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
    final colors = context.watch<ThemeProvider>().auroraColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraPainter(
                animation: _controller,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.animation,
    required this.colors,
    required this.isDark,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Solid base color first.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.baseBackground(isDark),
    );

    final t = animation.value * 2 * math.pi;
    final glowAlpha = isDark ? 0.50 : 0.42;
    final radius = size.longestSide * 0.62;

    for (var i = 0; i < colors.length && i < 3; i++) {
      final phase = i * 2.1;
      final center = Offset(
        size.width * (0.5 + 0.42 * math.sin(t + phase)),
        size.height * (0.5 + 0.38 * math.cos(t * 0.8 + phase * 1.3)),
      );

      final shader = RadialGradient(
        colors: [
          colors[i].withValues(alpha: glowAlpha),
          colors[i].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.colors != colors;
  }
}
