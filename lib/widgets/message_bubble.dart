import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/message.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'glass_card.dart';
import 'markdown_view.dart';
import 'typing_indicator.dart';

/// One message in the chat.
/// - Your messages: a colored bubble on the right.
/// - AI answers: a glass card on the left with Copy and Regenerate buttons.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showRegenerate = false,
    this.onRegenerate,
  });

  final ChatMessage message;

  /// True only for the very last answer, so it can be asked again.
  final bool showRegenerate;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    // Only brand-new messages slide in. Old ones just appear (so scrolling is calm).
    final fresh = DateTime.now().difference(message.createdAt).inSeconds < 3;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fresh ? 0.0 : 1.0, end: 1.0),
      duration: fresh ? const Duration(milliseconds: 380) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: message.isUser
            ? _buildUserBubble(context)
            : _buildAssistantBubble(context),
      ),
    );
  }

  // ---------- Your message ----------

  Widget _buildUserBubble(BuildContext context) {
    final accent = context.watch<ThemeProvider>().accent;
    final haptics = context.read<SettingsProvider>().haptics;
    final width = MediaQuery.of(context).size.width;
    final hsl = HSLColor.fromColor(accent);
    final second = hsl
        .withHue((hsl.hue + 28) % 360)
        .withLightness((hsl.lightness * 0.9).clamp(0.2, 0.8))
        .toColor();

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.82),
        child: GestureDetector(
          onLongPress: () {
            AppUtils.mediumHaptic(haptics);
            AppUtils.copyText(context, message.content);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, second],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasAttachments) ...[
                  _buildAttachmentList(),
                  if (message.content.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A simple list of the files that were sent with this message.
  Widget _buildAttachmentList() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in message.attachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor((a['type'] ?? 'file').toString()),
                    size: 15, color: Colors.white),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    (a['name'] ?? 'file').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // ---------- AI answer ----------

  Widget _buildAssistantBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.watch<ThemeProvider>().accent;
    final width = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark, accent),
            const SizedBox(height: 6),
            GlassCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _buildAnswerBody(isDark),
            ),
            if (!message.isStreaming) _buildActions(context, isDark, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color accent) {
    final name = message.modelName.trim();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 12, color: Colors.white),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(isDark),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerBody(bool isDark) {
    if (message.isError) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: Color(0xFFEF4444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
          ),
        ],
      );
    }

    if (message.isStreaming && message.content.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: TypingIndicator(),
      );
    }

    return MarkdownView(data: message.content);
  }

  Widget _buildActions(BuildContext context, bool isDark, Color accent) {
    final haptics = context.read<SettingsProvider>().haptics;
    final secondary = AppTheme.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!message.isError)
            _ActionButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy',
              color: secondary,
              onTap: () {
                AppUtils.lightHaptic(haptics);
                AppUtils.copyText(context, message.content);
              },
            ),
          if (showRegenerate && onRegenerate != null)
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: message.isError ? 'Try again' : 'Regenerate',
              color: accent,
              onTap: () {
                AppUtils.lightHaptic(haptics);
                onRegenerate!();
              },
            ),
          const SizedBox(width: 6),
          Text(
            AppUtils.formatTime(message.createdAt),
            style: TextStyle(fontSize: 11.5, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// A small round icon button under an answer.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
    );
  }
}
