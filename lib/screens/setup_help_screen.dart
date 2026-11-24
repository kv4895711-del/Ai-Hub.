import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/gateway_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';

/// Step-by-step help for the one-time Termux setup.
/// The script text below must match tools/startgateway.sh.
const String _allowExternalCommand =
    'mkdir -p ~/.termux && (grep -q "^allow-external-apps" ~/.termux/termux.properties 2>/dev/null '
    '|| echo "allow-external-apps = true" >> ~/.termux/termux.properties)';

const String _createScriptCommand = r'''cat > ~/startgateway.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# AI Hub: starts the FreeLLMAPI gateway in the background (if it is not already running).
GATEWAY_DIR="$HOME/freellmapi"
LOG_FILE="$HOME/gateway.log"
URL="http://localhost:3001"

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock
fi

if curl -s --max-time 3 "$URL" >/dev/null 2>&1; then
  echo "Gateway already running."
  exit 0
fi

if [ ! -d "$GATEWAY_DIR" ]; then
  echo "ERROR: $GATEWAY_DIR not found. Install FreeLLMAPI first." >> "$LOG_FILE"
  exit 1
fi

cd "$GATEWAY_DIR" || exit 1
nohup npm run dev >> "$LOG_FILE" 2>&1 &
echo "Gateway starting. Log: $LOG_FILE"
exit 0
EOF
chmod +x ~/startgateway.sh''';

class SetupHelpScreen extends StatefulWidget {
  const SetupHelpScreen({super.key});

  @override
  State<SetupHelpScreen> createState() => _SetupHelpScreenState();
}

class _SetupHelpScreenState extends State<SetupHelpScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GatewayProvider>().check();
    });
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                  children: [
                    _buildStatusCard(isDark),
                    const SizedBox(height: 16),
                    _buildStep(
                      isDark,
                      number: 1,
                      title: 'Install Termux and FreeLLMAPI',
                      children: [
                        _paragraph(
                          isDark,
                          'Install Termux from F-Droid (not the Play Store '
                          'version). Then install FreeLLMAPI in Termux so that '
                          'the command "npm run dev" works inside the folder '
                          '~/freellmapi.',
                        ),
                      ],
                    ),
                    _buildStep(
                      isDark,
                      number: 2,
                      title: 'Let other apps run Termux commands',
                      children: [
                        _paragraph(
                          isDark,
                          'Copy this command and paste it in Termux. Then '
                          'close Termux completely and open it again.',
                        ),
                        _CodeBox(code: _allowExternalCommand),
                      ],
                    ),
                    _buildStep(
                      isDark,
                      number: 3,
                      title: 'Create the start script',
                      children: [
                        _paragraph(
                          isDark,
                          'Copy this whole block and paste it in Termux once. '
                          'It creates ~/startgateway.sh, which AI Hub uses to '
                          'start the gateway.',
                        ),
                        _CodeBox(code: _createScriptCommand, maxHeight: 160),
                      ],
                    ),
                    _buildStep(
                      isDark,
                      number: 4,
                      title: 'Allow AI Hub to run Termux commands',
                      children: [
                        _paragraph(
                          isDark,
                          'Tap the button and allow the pop-up. If no pop-up '
                          'appears, open the app settings and turn on '
                          '"Run commands in Termux environment" under '
                          'Additional permissions.',
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionButtons(),
                      ],
                    ),
                    _buildStep(
                      isDark,
                      number: 5,
                      title: 'Start and test',
                      children: [
                        _paragraph(
                          isDark,
                          'Use "Start gateway" at the top of this page. If it '
                          'does not start, open Termux, run ~/startgateway.sh '
                          'and read the log with: cat ~/gateway.log',
                        ),
                      ],
                    ),
                    _buildStep(
                      isDark,
                      number: 6,
                      title: 'Keep it running',
                      children: [
                        _paragraph(
                          isDark,
                          'In Android Settings > Apps > Termux > Battery, '
                          'choose "Unrestricted". Without it, Android may stop '
                          'Termux when the screen is off.',
                        ),
                      ],
                    ),
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

  Widget _buildTopBar(bool isDark) {
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
              'Setup help',
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

  // ---------- Status card ----------

  Widget _buildStatusCard(bool isDark) {
    final accent = context.watch<ThemeProvider>().accent;

    return Consumer<GatewayProvider>(
      builder: (context, gateway, _) {
        final connected = gateway.isConnected;
        final Widget icon;
        if (gateway.isBusy || gateway.isStarting) {
          icon = const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          );
        } else if (connected) {
          icon = const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22C55E),
            size: 24,
          );
        } else {
          icon = const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF59E0B),
            size: 24,
          );
        }

        return GlassCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gateway.message,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: AppTheme.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: gateway.isBusy || gateway.isStarting
                          ? null
                          : () => gateway.ensureRunning(force: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Start gateway'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: gateway.isBusy || gateway.isStarting
                          ? null
                          : () => gateway.check(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary(isDark),
                        side: BorderSide(color: AppTheme.glassBorder(isDark)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Check again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Steps ----------

  Widget _buildStep(
    bool isDark, {
    required int number,
    required String title,
    required List<Widget> children,
  }) {
    final accent = context.watch<ThemeProvider>().accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _paragraph(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppTheme.textSecondary(isDark),
        ),
      ),
    );
  }

  Widget _buildPermissionButtons() {
    final gateway = context.read<GatewayProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.read<ThemeProvider>().accent;

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () async {
              await gateway.requestPermission();
              if (!mounted) return;
              AppUtils.showSnack(
                context,
                'Allow the pop-up, then tap "Check again" at the top.',
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Allow permission'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: gateway.openAppSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary(isDark),
              side: BorderSide(color: AppTheme.glassBorder(isDark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('App settings'),
          ),
        ),
      ],
    );
  }
}

/// A box that shows a command in monospace, with a Copy button.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code, this.maxHeight = 110});

  final String code;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.read<ThemeProvider>().accent;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => AppUtils.copyText(context, code),
              icon: Icon(Icons.copy_rounded, size: 16, color: accent),
              label: Text('Copy', style: TextStyle(color: accent)),
            ),
          ),
        ],
      ),
    );
  }
}
