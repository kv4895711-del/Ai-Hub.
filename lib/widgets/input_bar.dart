import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/attachment.dart';
import '../providers/models_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'attachment_chip.dart';
import 'attachment_sheet.dart';
import 'glass_card.dart';
import 'mic_button.dart';
import 'model_chip.dart';
import 'model_sheet.dart';

/// Neeche ka chat box: model chip, "+" button, text field, mic aur Send.
/// Jawab likhte waqt Send button Stop ban jata hai.
///
/// onSend ko text aur attachments (plain maps) milte hain:
///   onSend: (text, attachments) =>
///       chat.sendMessage(text, attachments: attachments)
class InputBar extends StatefulWidget {
  const InputBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final bool isGenerating;
  final void Function(String text, List<Map<String, dynamic>> attachments)
      onSend;
  final VoidCallback onStop;

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  static const int _maxAttachments = 6;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<Attachment> _attachments = [];

  bool _hasText = false;

  // Voice: dictation shuru hone se pehle ka text.
  String? _dictationBase;
  bool _wasListening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  bool get _canSend => _hasText || _attachments.isNotEmpty;

  bool get _haptics => context.read<SettingsProvider>().haptics;

  // ---------- Actions ----------

  void _send() {
    if (widget.isGenerating || !_canSend) return;

    final voice = context.read<VoiceService>();
    if (voice.isListening) voice.cancelListening();

    final text = _controller.text.trim();
    final list = _attachments.map((a) => a.toJson()).toList();

    AppUtils.lightHaptic(_haptics);
    widget.onSend(text, list);

    _dictationBase = null;
    _controller.clear();
    setState(() => _attachments.clear());
  }

  void _stop() {
    AppUtils.mediumHaptic(_haptics);
    widget.onStop();
  }

  void _openModels() {
    _focus.unfocus();
    AppUtils.selectionHaptic(_haptics);
    ModelSheet.show(context);
  }

  Future<void> _pickAttachments() async {
    if (widget.isGenerating) return;
    _focus.unfocus();
    AppUtils.selectionHaptic(_haptics);

    final result = await AttachmentSheet.show(context);
    if (!mounted || result == null) return;

    if (result.hasError) {
      AppUtils.showSnack(context, result.error!);
    }
    if (result.attachments.isEmpty) return;

    final room = _maxAttachments - _attachments.length;
    if (room <= 0) {
      AppUtils.showSnack(
          context, 'Ek message mein max $_maxAttachments attachments.');
      return;
    }

    final toAdd = result.attachments.take(room).toList();
    setState(() => _attachments.addAll(toAdd));

    if (result.attachments.length > room) {
      AppUtils.showSnack(
          context, 'Sirf $_maxAttachments attachments jod paye.');
    }
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    AppUtils.lightHaptic(_haptics);
    setState(() => _attachments.removeAt(index));
  }

  /// Mic se jo bola gaya, use pehle likhe text ke aage jodta hai.
  void _onVoiceText(String spoken, bool isFinal) {
    _dictationBase ??= _controller.text;
    final base = _dictationBase!.trimRight();
    final text = base.isEmpty ? spoken : '$base $spoken';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mic abhi chalu hua? To us waqt ka text yaad rakho.
    final listening =
        context.select<VoiceService, bool>((v) => v.isListening);
    if (listening && !_wasListening) {
      _dictationBase = _controller.text;
    }
    _wasListening = listening;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: GlassCard(
          radius: 28,
          strength: 1.4,
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model chip
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: ModelChip(onTap: _openModels),
              ),

              // Attachments
              if (_attachments.isNotEmpty) _buildAttachments(),
              _buildHint(isDark),

              // Plus, text field, mic, send
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPlusButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: AppTheme.textPrimary(isDark),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message ${AppConstants.appName}',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary(isDark),
                          ),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!widget.isGenerating)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1, right: 4),
                      child: MicButton(
                        size: 40,
                        enabled: !widget.isGenerating,
                        onText: _onVoiceText,
                      ),
                    ),
                  _buildActionButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _attachments.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AttachmentChip(
                  attachment: _attachments[i],
                  onRemove: () => _removeAttachment(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Image ke liye vision model na ho, ya video ho, to chhota sa hint.
  Widget _buildHint(bool isDark) {
    final hasImage = _attachments.any((a) => a.isImage);
    final hasVideo = _attachments.any((a) => a.isVideo);
    if (!hasImage && !hasVideo) return const SizedBox.shrink();

    final mayReadImages =
        context.watch<ModelsProvider>().selectedMayReadImages;

    String? message;
    if (hasVideo) {
      message = 'Video model nahi padh sakta, sirf uska naam jayega.';
    } else if (hasImage && !mayReadImages) {
      message = 'Ye model shayad image na padh paye. Vision model chuno.';
    }
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlusButton() {
    final accent = context.watch<ThemeProvider>().accent;
    final disabled = widget.isGenerating;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Material(
          color: accent.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: disabled ? null : _pickAttachments,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.add_rounded, color: accent, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final accent = context.watch<ThemeProvider>().accent;
    final generating = widget.isGenerating;
    final enabled = generating || _canSend;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: GestureDetector(
          key: ValueKey<bool>(generating),
          onTap: generating ? _stop : (_canSend ? _send : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? accent : accent.withValues(alpha: 0.30),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              generating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
