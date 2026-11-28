import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../providers/gateway_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import 'setup_help_screen.dart';

/// Settings: gateway address and key, connection test, appearance, haptics.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _version = '1.0.0';
  static const Color _okColor = Color(0xFF22C55E);
  static const Color _badColor = Color(0xFFEF4444);

  late final SettingsProvider _settings;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;

  bool _showKey = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _urlCtrl = TextEditingController(text: _settings.baseUrl);
    _keyCtrl = TextEditingController(text: _settings.apiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  // ---------- Actions ----------

  /// Saves the address and key from the text boxes.
  Future<void> _commit() async {
    await _settings.setBaseUrl(_urlCtrl.text);
    await _settings.setApiKey(_keyCtrl.text);
    if (_urlCtrl.text.trim() != _settings.baseUrl) {
      _urlCtrl.text = _settings.baseUrl;
    }
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      AppUtils.showSnack(context, 'The clipboard is empty.');
      return;
    }
    setState(() => _keyCtrl.text = text);
    await _commit();
  }

  Future<void> _resetAddress() async {
    await _settings.resetBaseUrl();
    if (!mounted) return;
    setState(() => _urlCtrl.text = _settings.baseUrl);
    AppUtils.showSnack(context, 'Address reset.');
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    await _commit();
    if (!mounted) return;
    setState(() {
      _testing = true;
      _testMessage = null;
    });

    String message;
    bool ok = false;
    try {
      final count = await ApiService().testConnection(
        baseUrl: _settings.baseUrl,
        apiKey: _settings.apiKey,
      );
      ok = true;
      message = count > 0
          ? 'Connected. $count models are available.'
          : 'Connected, but the gateway lists no models yet.';
    } on ApiException catch (e) {
      message = e.friendlyMessage;
    } catch (_) {
      message = 'The test failed. Check the address and try again.';
    }

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testMessage = message;
    });
    context.read<GatewayProvider>().check();
  }

  Future<void> _startGateway() async {
    AppUtils.showSnack(context, 'Asking Termux to start the gateway...');
    await context.read<GatewayProvider>().ensureRunning(force: true);
    if (!mounted) return;
    final gateway = context.read<GatewayProvider>();
    AppUtils.showSnack(context, gateway.message);
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
    final settings = context.watch<SettingsProvider>();
    final theme = context.watch<ThemeProvider>();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
                      _buildGatewaySection(isDark),
                      _buildBehaviorSection(isDark, settings),
                      _buildAppearanceSection(isDark, settings, theme),
                      _buildAboutSection(isDark),
                    ],
                  ),
                ),
              ],
            ),
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
              'Settings',
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

  // ---------- Sections ----------

  Widget _section(bool isDark, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(isDark),
              ),
            ),
          ),
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  // ---------- Gateway ----------

  Widget _buildGatewaySection(bool isDark) {
    final secondary = AppTheme.textSecondary(isDark);
    final ink = AppTheme.accentFor(isDark);
    final onInk = AppTheme.onAccentFor(isDark);

    return _section(isDark, 'Gateway', [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          onEditingComplete: () {
            _commit();
            FocusScope.of(context).nextFocus();
          },
          decoration: InputDecoration(
            labelText: 'Gateway address',
            hintText: AppConstants.defaultBaseUrl,
            border: InputBorder.none,
            suffixIcon: IconButton(
              tooltip: 'Reset address',
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              onPressed: _resetAddress,
            ),
          ),
        ),
      ),
      _divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: TextField(
          controller: _keyCtrl,
          obscureText: !_showKey,
          autocorrect: false,
          enableSuggestions: false,
          onEditingComplete: () {
            _commit();
            FocusScope.of(context).unfocus();
          },
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: 'freellmapi-...',
            border: InputBorder.none,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  onPressed: _pasteKey,
                ),
                IconButton(
                  tooltip: _showKey ? 'Hide' : 'Show',
                  icon: Icon(
                    _showKey
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text(
          'Copy the "unified API key" from the FreeLLMAPI dashboard '
          '(Keys page). It is stored in the phone\'s secure storage.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: secondary),
        ),
      ),
      _divider(),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testConnection,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: onInk,
                  disabledBackgroundColor: ink.withValues(alpha: 0.35),
                  disabledForegroundColor: onInk.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _testing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onInk,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 20),
                label: Text(_testing ? 'Testing...' : 'Test connection'),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _testMessage == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testOk
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            size: 20,
                            color: _testOk ? _okColor : _badColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: AppTheme.textPrimary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ---------- Behavior ----------

  Widget _buildBehaviorSection(bool isDark, SettingsProvider settings) {
    return _section(isDark, 'Gateway in Termux', [
      SwitchListTile(
        title: const Text('Start gateway automatically'),
        subtitle: const Text('Starts it through Termux when the app opens'),
        value: settings.autoStart,
        onChanged: (v) => settings.setAutoStart(v),
      ),
      _divider(),
      ListTile(
        leading: const Icon(Icons.play_circle_outline_rounded),
        title: const Text('Start gateway now'),
        onTap: _startGateway,
      ),
      _divider(),
      ListTile(
        leading: const Icon(Icons.help_outline_rounded),
        title: const Text('Setup help'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _openHelp,
      ),
    ]);
  }

  // ---------- Appearance ----------

  Widget _buildAppearanceSection(
    bool isDark,
    SettingsProvider settings,
    ThemeProvider theme,
  ) {
    final ink = AppTheme.accentFor(isDark);
    final onInk = AppTheme.onAccentFor(isDark);
    final primary = AppTheme.textPrimary(isDark);

    Widget segment(String label, ThemeMode mode) {
      final selected = theme.mode == mode;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? onInk : primary,
          ),
        ),
      );
    }

    return _section(isDark, 'Appearance', [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<ThemeMode>(
            groupValue: theme.mode,
            thumbColor: ink,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
            children: {
              ThemeMode.system: segment('System', ThemeMode.system),
              ThemeMode.light: segment('Light', ThemeMode.light),
              ThemeMode.dark: segment('Dark', ThemeMode.dark),
            },
            onValueChanged: (mode) {
              if (mode != null) theme.setMode(mode);
            },
          ),
        ),
      ),
      _divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            const Text('Text size'),
            const Spacer(),
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 16 * settings.fontScale,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
      Slider(
        value: settings.fontScale,
        min: AppConstants.minFontScale,
        max: AppConstants.maxFontScale,
        divisions: 11,
        onChanged: (v) => settings.setFontScale(v),
      ),
      _divider(),
      SwitchListTile(
        title: const Text('Haptic feedback'),
        subtitle: const Text('Small vibrations when you tap'),
        value: settings.haptics,
        onChanged: (v) => settings.setHaptics(v),
      ),
    ]);
  }

  // ---------- About ----------

  Widget _buildAboutSection(bool isDark) {
    return _section(isDark, 'About', [
      const ListTile(
        leading: Icon(Icons.auto_awesome_rounded),
        title: Text(AppConstants.appName),
        subtitle: Text('Version $_version'),
      ),
      _divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Text(
          '${AppConstants.appName} talks to the FreeLLMAPI gateway on this '
          'phone. Free models have rate limits, so a reply can stop '
          'sometimes. Your key never leaves your phone except to reach your '
          'own gateway.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppTheme.textSecondary(isDark),
          ),
        ),
      ),
    ]);
  }
}
