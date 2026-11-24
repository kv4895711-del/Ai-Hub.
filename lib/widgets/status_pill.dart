import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gateway_provider.dart';
import '../theme/app_theme.dart';

/// A small pill that shows whether the gateway is Connected, Starting or Offline.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, this.onTap});

  final VoidCallback? onTap;

  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);

  Color _colorFor(GatewayStatus status) {
    switch (status) {
      case GatewayStatus.connected:
        return _green;
      case GatewayStatus.unknown:
      case GatewayStatus.checking:
      case GatewayStatus.starting:
        return _orange;
      case GatewayStatus.offline:
      case GatewayStatus.termuxMissing:
      case GatewayStatus.needsPermission:
        return _red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gateway = context.watch<GatewayProvider>();
    final color = _colorFor(gateway.status);
    final working = gateway.status == GatewayStatus.checking ||
        gateway.status == GatewayStatus.starting ||
        gateway.status == GatewayStatus.unknown;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color, pulsing: working),
            const SizedBox(width: 7),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                gateway.label,
                key: ValueKey<String>(gateway.label),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small colored dot. It gently pulses while something is in progress.
class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                blurRadius: 4 + 6 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
