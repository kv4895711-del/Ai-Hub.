import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

/// Mic button: dabao to sunna shuru, dobara dabao to band.
/// Sunte waqt pulse ring aur waveform bars dikhte hain.
///
/// Use (input bar mein):
///   MicButton(
///     enabled: !isGenerating,
///     onText: (text, isFinal) { _controller.text = text; },
///   )
///
/// Zaroori: main.dart mein VoiceService ka ChangeNotifierProvider hona chahiye.
class MicButton extends StatefulWidget {
  /// Jo bola gaya uska text. isFinal true ho to wo aakhri result hai.
  final void Function(String text, bool isFinal) onText;

  /// false ho to button dhundhla ho jata hai aur dabta nahi.
  final bool enabled;

  /// Button ka size.
  final double size;

  const MicButton({
    super.key,
    required this.onText,
    this.enabled = true,
    this.size = 44,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  VoiceService? _voice;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    final v = _voice;
    if (v != null && v.isListening) {
      // Widget hatne ke dauran notify na ho, isliye microtask.
      Future.microtask(() => v.cancelListening());
    }
    _anim.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final voice = context.read<VoiceService>();
    _voice = voice;
    final haptics = context.read<SettingsProvider>().haptics;

    if (voice.isListening) {
      AppUtils.lightHaptic(haptics);
      await voice.stopListening();
      return;
    }

    AppUtils.mediumHaptic(haptics);
    final ok = await voice.startListening(
      onText: (text, isFinal) {
        if (!mounted) return;
        widget.onText(text, isFinal);
      },
      onDone: _showErrorIfAny,
    );
    if (!ok && mounted) {
      _showErrorIfAny();
    }
  }

  void _showErrorIfAny() {
    if (!mounted) return;
    final voice = _voice ?? context.read<VoiceService>();
    final err = voice.error;
    if (err == null || err.isEmpty) return;
    voice.clearError();
    AppUtils.showSnack(context, err);
  }

  void _syncAnimation(bool listening) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (listening && !_anim.isAnimating) {
        _anim.repeat();
      } else if (!listening && _anim.isAnimating) {
        _anim.stop();
        _anim.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final listening = voice.isListening;
    final size = widget.size;

    _syncAnimation(listening);

    final Color fill = listening ? accent : AppTheme.glassFill(isDark);
    final Color iconColor = listening ? Colors.white : accent;

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Tooltip(
        message: listening ? 'Band karo' : 'Bolkar likho',
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final t = _anim.value;
              final level = voice.soundLevel;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (listening)
                    IgnorePointer(
                      child: Transform.scale(
                        scale: 1.0 + 0.45 * t + 0.35 * level,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withOpacity(
                              ((1 - t) * 0.35).clamp(0.0, 1.0).toDouble(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: fill,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: listening
                            ? Colors.transparent
                            : AppTheme.glassBorder(isDark),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.enabled ? _onTap : null,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Center(
                          child: listening
                              ? _bars(t, level, iconColor)
                              : Icon(Icons.mic_rounded,
                                  color: iconColor, size: size * 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 5 chhoti bars jo awaaz ke saath upar-neeche hoti hain.
  Widget _bars(double t, double level, Color color) {
    const count = 5;
    final maxH = widget.size * 0.5;
    final minH = 4.0;
    final lvl = 0.15 + 0.85 * level;

    final List<Widget> bars = [];
    for (int i = 0; i < count; i++) {
      final wave = 0.55 + 0.45 * math.sin(2 * math.pi * t + i * 1.1);
      final h = minH + (maxH - minH) * lvl * wave;
      if (i > 0) bars.add(const SizedBox(width: 3));
      bars.add(Container(
        width: 3,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars,
    );
  }
}
