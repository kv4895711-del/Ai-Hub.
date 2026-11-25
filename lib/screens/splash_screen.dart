import 'package:flutter/cupertino.dart';
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
import 'setup_help_screen.dart';

/// Pehli screen: gateway check karti hai (aur zaroorat ho to start karwati hai),
/// phir chat screen par le jati hai.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final GatewayProvider _gateway;

  bool _navigated = false;
  bool _minTimePassed = false;
  bool _checkDone = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _gateway = context.read<GatewayProvider>();
    _gateway.addListener(_onGatewayChanged);

    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _minTimePassed = true;
      _maybeContinue();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _gateway.removeListener(_onGatewayChanged);
    _anim.dispose();
    super.dispose();
  }

  // ---------- Logic ----------

  Future<void> _begin() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    try {
      if (settings.hasKey && settings.autoStart) {
        await _gateway.ensureRunning();
      } else {
        await _gateway.check();
      }
    } catch (_) {
      // Error gateway provider khud status mein dikhata hai.
    }
    try {
      _gateway.startMonitoring();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _checkDone = true);
    _maybeContinue();
  }

  void _onGatewayChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeContinue();
  }

  /// Agar gateway chal raha hai (ya key hi nahi hai), seedha chat par jao.
  /// Warna yahin ruko aur options dikhao.
  void _maybeContinue() {
    if (_navigated || !mounted) return;
    if (!_minTimePassed || !_checkDone) return;

    final hasKey = context.read<SettingsProvider>().hasKey;
    if (_gateway.isConnected || !hasKey) {
      _goToChat();
    }
  }

  void _goToChat() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const ChatScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _retry() async {
    if (_gateway.isBusy) return;
    try {
      await _gateway.ensureRunning(force: true);
    } catch (_) {}
    if (!mounted) return;
    _maybeContinue();
  }

  void _openHelp() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SetupHelpScreen()),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accent;
    final second =
        theme.auroraColors.length > 1 ? theme.auroraColors[1] : accent;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(accent, second),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConstants.appTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildStatusCard(isDark, accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color accent, Color second) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_anim.value);
        return Transform.scale(
          scale: 1.0 + 0.06 * t,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, second],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30 + 0.25 * t),
                  blurRadius: 24 + 18 * t,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 46,
      ),
    );
  }

  Widget _buildStatusCard(bool isDark, Color accent) {
    final gateway = context.watch<GatewayProvider>();
    final hasKey = context.select<SettingsProvider, bool>((s) => s.hasKey);

    final String label = gateway.label ?? '';
    final String message = gateway.message ?? '';
    final int? secs = gateway.secondsLeft;

    final bool busy = gateway.isBusy || !_checkDone;
    final bool problem = _checkDone && !gateway.isConnected && hasKey && !busy;

    String title;
    String? body;

    if (busy) {
      title = gateway.isStarting ? 'Gateway start ho raha hai...' : 'Check ho raha hai...';
      body = (gateway.isStarting && secs != null && secs > 0)
          ? 'Lagbhag $secs second aur lagenge.'
          : null;
    } else if (problem) {
      title = label.isEmpty ? 'Gateway se connect nahi hua' : label;
      body = message.isEmpty ? null : message;
    } else {
      title = 'Taiyaar!';
      body = null;
    }

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: accent,
                  ),
                )
              else
                Icon(
                  problem
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,
                  size: 22,
                  color: problem ? const Color(0xFFEF4444) : accent,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppTheme.textSecondary(isDark),
                ),
              ),
            ),
          ],
          if (problem) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _openHelp,
                  child: Text('Help', style: TextStyle(color: accent)),
                ),
                TextButton(
                  onPressed: _retry,
                  child: Text('Dobara try', style: TextStyle(color: accent)),
                ),
                FilledButton(
                  onPressed: _goToChat,
                  child: const Text('Aise hi aage badho'),
                ),
              ],
            ),
          ] else if (!busy && !hasKey) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _goToChat,
                child: const Text('Aage badho'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
