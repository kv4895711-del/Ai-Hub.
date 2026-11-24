import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

/// First screen: shows the logo, checks the gateway (and starts it through
/// Termux if needed), then fades into the chat screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _skipTimer;
  bool _navigated = false;
  bool _showSkip = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // If the gateway takes long to start, let the user continue anyway.
    _skipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSkip = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    final gateway = context.read<GatewayProvider>();
    final started = DateTime.now();

    await gateway.ensureRunning();

    // Keep the splash on screen for at least a moment so it does not flash.
    const minimum = Duration(milliseconds: 1400);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    _goToChat();
  }

  void _goToChat() {
    if (_navigated || !mounted) return;
    _navigated = true;

    context.read<GatewayProvider>().startMonitoring();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const ChatScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();
    final hasKey = context.select<SettingsProvider, bool>((s) => s.hasKey);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(theme),
                  const SizedBox(height: 28),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: AppTheme.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: _buildStatusCard(isDark),
                  ),
                  const SizedBox(height: 14),
                  if (!hasKey)
                    Text(
                      'Tip: add your gateway key in Settings after this screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary(isDark),
                      ),
                    ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    opacity: _showSkip ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: _showSkip ? _goToChat : null,
                      child: Text(
                        'Continue anyway',
                        style: TextStyle(color: theme.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeProvider theme) {
    final second = theme.auroraColors.length > 1
        ? theme.auroraColors[1]
        : theme.accent;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1 + 0.05 * t,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.accent, second],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.30 + 0.25 * t),
                  blurRadius: 30 + 22 * t,
                  spreadRadius: 2 + 4 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 48,
        color: Colors.white,
      ),
    );
  }
