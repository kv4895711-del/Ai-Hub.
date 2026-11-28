import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/attachment.dart';
import '../models/message.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import 'attachment_chip.dart';
import 'glass_card.dart';
import 'markdown_view.dart';
import 'typing_indicator.dart';

/// Chat ka ek message.
/// - Tumhare messages: ink-color bubble right side par (Dark mein safed, Light mein kaala).
/// - AI ke jawab: glass card left side par, Copy, Read aloud aur Regenerate ke saath.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showRegenerate = false,
    this.onRegenerate,
  });

  final ChatMessage message;

  /// Sirf sabse aakhri jawab ke liye true, taaki use dobara pooch sako.
  final bool showRegenerate;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    // Sirf bilkul naye messages slide hote hain. Purane seedhe dikhte hain.
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

  // ---------- Tumhara message ----------

  Widget _buildUserBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = AppTheme.accentFor(isDark);
    final textColor = AppTheme.onAccentFor(isDark);
    final haptics = context.read<SettingsProvider>().haptics;
    final width = MediaQuery.of(context).size.width;

    final hasText = message.content.trim().isNotEmpty;
    final hasFiles = message.hasAttachments;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFiles) _buildAttachmentChips(context),
            if (hasFiles && hasText) const SizedBox(height: 6),
            if (hasText)
              GestureDetector(
                onLongPress: () {
                  AppUtils.mediumHaptic(haptics);
                  AppUtils.copyText(context, message.content);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Message ke saath bheji gayi files ke chips (bubble ke upar).
  Widget _buildAttachmentChips(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final map in message.attachments)
          Builder(
            builder: (ctx) {
              final a = Attachment.fromJson(map);
              return AttachmentChip(
                attachment: a,
                onTap: a.isImage ? () => _openImage(ctx, a) : null,
              );
            },
          ),
      ],
    );
  }

  /// Image par tap karne par bada preview.
  void _openImage(BuildContext context, Attachment a) {
    if (a.path.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(a.path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_rounded,
                      size: 48, color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- AI ka jawab ----------

  Widget _buildAssistantBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.accentFor(isDark);
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
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 12,
              color: AppTheme.onAccentFor(isDark),
            ),
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
    final canRead = !message.isError && message.content.trim().isNotEmpty;
    final speaking = canRead &&
        context.select<VoiceService, bool>(
          (v) => v.isSpeakingId(message.id),
        );

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
          if (canRead)
            _ActionButton(
              icon: speaking
                  ? Icons.stop_circle_rounded
                  : Icons.volume_up_rounded,
              tooltip: speaking ? 'Rok do' : 'Padh kar sunao',
              color: speaking ? accent : secondary,
              onTap: () => _toggleReadAloud(context, haptics),
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

  Future<void> _toggleReadAloud(BuildContext context, bool haptics) async {
    final voice = context.read<VoiceService>();
    AppUtils.lightHaptic(haptics);
    await voice.speak(message.content, id: message.id);

    final err = voice.error;
    if (err != null && err.isNotEmpty && context.mounted) {
      voice.clearError();
      AppUtils.showSnack(context, err);
    }
  }
}

/// Jawab ke neeche ka chhota gol icon button.
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
