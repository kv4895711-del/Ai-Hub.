import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../providers/chat_provider.dart';
import '../providers/gateway_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/example_prompts.dart';
import '../widgets/glass_card.dart';
import '../widgets/input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/status_pill.dart';
import 'settings_screen.dart';
import 'setup_help_screen.dart';

/// The main screen: top bar, the conversation, and the input bar at the bottom.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scroll = ScrollController();

  /// True while the list is at (or near) the bottom, so new text keeps scrolling.
  bool _stick = true;

  String? _lastChatId;
  int _lastCount = 0;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  // ---------- Scrolling ----------

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final nearBottom = (position.maxScrollExtent - position.pixels) < 140;
    if (nearBottom != _stick && mounted) {
      setState(() => _stick = nearBottom);
    }
  }

  void _scheduleScroll({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Decides, on every rebuild, whether the list should scroll down.
  void _autoScroll(ChatProvider chat) {
    final messages = chat.messages;
    final count = messages.length;
    final length = messages.isEmpty ? 0 : messages.last.content.length;

    if (chat.currentChatId != _lastChatId) {
      _lastChatId = chat.currentChatId;
      _stick = true;
      _scheduleScroll(jump: true);
    } else if (count != _lastCount) {
      final lastIsUser = messages.isNotEmpty && messages.last.isUser;
      if (_stick || lastIsUser) {
        _stick = true;
        _scheduleScroll();
      }
    } else if (_stick && length != _lastLength) {
      _scheduleScroll(jump: true);
    }

    _lastCount = count;
    _lastLength = length;
  }

  // ---------- Actions ----------

  void _send(String text) {
    final settings = context.read<SettingsProvider>();
    if (!settings.hasKey) {
      AppUtils.showSnack(context, 'Add your gateway key in Settings first.');
      return;
    }
    AppUtils.lightHaptic(settings.haptics);
    _stick = true;
    context.read<ChatProvider>().sendMessage(text);
  }

  void _newChat() {
    AppUtils.selectionHaptic(context.read<SettingsProvider>().haptics);
    _stick = true;
    context.read<ChatProvider>().newChat();
  }

  void _openSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openHelp() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SetupHelpScreen()),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    _autoScroll(chat);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(chat),
              Expanded(
                child: Stack(
                  children: [
                    chat.messages.isEmpty
                        ? _buildEmptyState()
                        : _buildMessageList(chat),
                    Positioned(
                      right: 16,
                      bottom: 10,
                      child: _buildScrollDownButton(chat),
                    ),
                  ],
                ),
              ),
              _buildBanner(),
              InputBar(
                isGenerating: chat.isGenerating,
                onSend: _send,
                onStop: chat.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Top bar ----------

  Widget _buildTopBar(ChatProvider chat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = chat.currentChat?.title ?? AppConstants.appName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.edit_square,
            tooltip: 'New chat',
            onTap: _newChat,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    title,
                    key: ValueKey<String>(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(onTap: _openHelp),
              ],
            ),
          ),
          _GlassIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  // ---------- Messages ----------

  Widget _buildMessageList(ChatProvider chat) {
    final messages = chat.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];
        final isLast = i == messages.length - 1;
        return MessageBubble(
          key: ValueKey<String>(message.id),
          message: message,
          showRegenerate: isLast && !message.isUser && chat.canRegenerate,
          onRegenerate: chat.regenerate,
        );
      },
    );
  }

  Widget _buildScrollDownButton(ChatProvider chat) {
    final show = !_stick && chat.messages.isNotEmpty;
    return AnimatedScale(
      scale: show ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: _GlassIconButton(
        icon: Icons.keyboard_arrow_down_rounded,
        tooltip: 'Scroll to bottom',
        onTap: () {
          _stick = true;
          _scheduleScroll();
          setState(() {});
        },
      ),
    );
  }

  // ---------- Empty state ----------

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();
    final second =
        theme.auroraColors.length > 1 ? theme.auroraColors[1] : theme.accent;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.accent, second],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.35),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'How can I help?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppTheme.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask anything. Pick any free model.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppTheme.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 26),
              ExamplePrompts(onSelected: _send),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Banner (missing key / gateway offline) ----------

  Widget _buildBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasKey = context.select<SettingsProvider, bool>((s) => s.hasKey);
    final gateway = context.watch<GatewayProvider>();

    String? text;
    final actions = <Widget>[];
    final accent = context.read<ThemeProvider>().accent;

    if (!hasKey) {
      text = 'Add your gateway key to start chatting.';
      actions.add(
        TextButton(
          onPressed: _openSettings,
          child: Text('Open Settings', style: TextStyle(color: accent)),
        ),
      );
    } else if (gateway.status == GatewayStatus.offline ||
        gateway.status == GatewayStatus.termuxMissing ||
        gateway.status == GatewayStatus.needsPermission) {
      text = gateway.message;
      actions.add(
        TextButton(
          onPressed: gateway.isBusy
              ? null
              : () => context.read<GatewayProvider>().ensureRunning(force: true),
          child: Text('Start', style: TextStyle(color: accent)),
        ),
      );
      actions.add(
        TextButton(
          onPressed: _openHelp,
          child: Text('Help', style: TextStyle(color: accent)),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: GlassCard(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: AppTheme.textPrimary(isDark),
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
    );
  }
}

/// A round glass button used in the top bar.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: GlassCard(
        radius: 22,
        padding: EdgeInsets.zero,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: 22),
          onPressed: onTap,
        ),
      ),
    );
  }
}
