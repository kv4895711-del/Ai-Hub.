import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice input (speech_to_text) aur read-aloud (flutter_tts) ek jagah.
/// ChangeNotifier hai, isliye mic button isse watch kar sakta hai.
///
/// Use (mic):
///   voice.startListening(onText: (text, isFinal) { ... });
///   voice.stopListening();
/// Use (read aloud):
///   voice.speak(message.content, id: message.id);   // dobara dabane par ruk jata hai
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _disposed = false;

  bool _listening = false;
  bool _speaking = false;
  double _level = 0;
  String? _error;
  String? _speakingId;
  String? _localeId; // null = phone ki default bhasha
  String? _ttsLang;

  void Function(String text, bool isFinal)? _onText;
  VoidCallback? _onDone;

  static const int _maxSpeechChars = 3900;

  // ---------- getters ----------

  /// Mic abhi sun raha hai?
  bool get isListening => _listening;

  /// Abhi koi jawab bola ja raha hai?
  bool get isSpeaking => _speaking;

  /// Jis message ko bola ja raha hai uski id (agar di thi).
  String? get speakingId => _speakingId;

  /// Awaaz ka level 0.0 se 1.0 (waveform/pulse ke liye).
  double get soundLevel => _level;

  /// Aakhri error ka message (user ko dikhane layak). Null = koi error nahi.
  String? get error => _error;

  /// Speech recognition tayyar hai?
  bool get isAvailable => _sttReady;

  /// Is message ko abhi bola ja raha hai?
  bool isSpeakingId(String id) => _speaking && _speakingId == id;

  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  /// Bolne ki bhasha badlo, jaise 'hi_IN' ya 'en_US'. null = auto.
  void setLocale(String? localeId) {
    _localeId = localeId;
  }

  // ---------- speech to text ----------

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    try {
      final ok = await _stt.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      _sttReady = ok;
      if (ok) await _pickLocale();
      return ok;
    } catch (e) {
      debugPrint('VoiceService init error: $e');
      return false;
    }
  }

  Future<void> _pickLocale() async {
    if (_localeId != null) return;
    try {
      final locales = await _stt.locales();
      String? hindi;
      for (final l in locales) {
        final id = l.localeId;
        if (id.toLowerCase().startsWith('hi')) {
          if (id.toLowerCase() == 'hi_in') {
            hindi = id;
            break;
          }
          hindi ??= id;
        }
      }
      _localeId = hindi; // Hindi na mile to null (phone default)
    } catch (e) {
      debugPrint('VoiceService locale error: $e');
    }
  }

  /// Mic chalu karta hai. Mil gaya to true, nahi to false (error set hota hai).
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onText,
    VoidCallback? onDone,
  }) async {
    if (_listening) return true;
    await stopSpeaking();
    _error = null;

    final ok = await _initStt();
    if (!ok) {
      _error = 'Mic use nahi ho paya. Mic permission allow karo '
          'aur Google voice service check karo.';
      _safeNotify();
      return false;
    }

    _onText = onText;
    _onDone = onDone;
    _listening = true;
    _level = 0;
    _safeNotify();

    try {
      await _stt.listen(
        onResult: _handleResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: _localeId,
        onSoundLevelChange: _handleLevel,
      );
      return true;
    } catch (e) {
      debugPrint('VoiceService listen error: $e');
      _error = 'Voice input shuru nahi ho paya.';
      _finishListening();
      return false;
    }
  }

  /// Mic band karo (jo bola gaya wo final result mein aa jata hai).
  Future<void> stopListening() async {
    if (!_listening) return;
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
    }
    _finishListening();
  }

  /// Mic band karo aur jo suna wo phenk do.
  Future<void> cancelListening() async {
    _onText = null;
    if (!_listening) return;
    try {
      await _stt.cancel();
    } catch (e) {
      debugPrint('VoiceService cancel error: $e');
    }
    _finishListening();
  }

  void _handleResult(SpeechRecognitionResult r) {
    _onText?.call(r.recognizedWords, r.finalResult);
  }

  void _handleLevel(double level) {
    // Android par level lagbhag -2 se 10 tak aata hai.
    final n = ((level + 2) / 12).clamp(0.0, 1.0).toDouble();
    if ((n - _level).abs() < 0.05) return;
    _level = n;
    _safeNotify();
  }

  void _handleStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _finishListening();
    }
  }

  void _handleError(SpeechRecognitionError e) {
    final msg = e.errorMsg;
    if (msg.contains('no_match') || msg.contains('timeout')) {
      _error = 'Kuch sunai nahi diya. Dobara bolo.';
    } else if (msg.contains('permission')) {
      _error = 'Mic permission nahi hai. Phone Settings mein allow karo.';
    } else {
      _error = 'Voice input mein dikkat: $msg';
    }
    _finishListening();
  }

  void _finishListening() {
    if (!_listening) return;
    _listening = false;
    _level = 0;
    _safeNotify();
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  // ---------- text to speech (read aloud) ----------

  Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      _tts.setStartHandler(() {});
      _tts.setCompletionHandler(() {
        _speaking = false;
        _speakingId = null;
        _safeNotify();
      });
      // stop() par cancel aata hai; state stopSpeaking() khud sambhalta hai.
      _tts.setCancelHandler(() {});
      _tts.setErrorHandler((dynamic message) {
        debugPrint('TTS error: $message');
        _speaking = false;
        _speakingId = null;
        _safeNotify();
      });
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ttsReady = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Text bolta hai. Same [id] wala message pehle se bol raha ho
  /// to use rok deta hai (toggle).
  Future<void> speak(String text, {String? id}) async {
    final clean = cleanForSpeech(text);
    if (clean.isEmpty) return;

    if (_speaking && id != null && id == _speakingId) {
      await stopSpeaking();
      return;
    }

    await stopSpeaking();
    if (_listening) await cancelListening();
    await _initTts();
    if (!_ttsReady) {
      _error = 'Read aloud shuru nahi ho paya.';
      _safeNotify();
      return;
    }

    _error = null;
    _speakingId = id;
    _speaking = true;
    _safeNotify();

    try {
      final lang = _langFor(clean);
      if (lang != _ttsLang) {
        await _tts.setLanguage(lang);
        _ttsLang = lang;
      }
      final r = await _tts.speak(clean);
      if (r != 1) {
        _speaking = false;
        _speakingId = null;
        _error = 'Read aloud nahi chal paya. Phone ki TTS service check karo.';
        _safeNotify();
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _speaking = false;
      _speakingId = null;
      _error = 'Read aloud nahi chal paya.';
      _safeNotify();
    }
  }

  Future<void> stopSpeaking() async {
    final wasSpeaking = _speaking;
    _speaking = false;
    _speakingId = null;
    if (wasSpeaking) _safeNotify();
    if (!_ttsReady) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  /// Devanagari akshar zyada ho to Hindi, warna English voice.
  String _langFor(String text) {
    int dev = 0;
    for (final r in text.runes) {
      if (r >= 0x0900 && r <= 0x097F) dev++;
    }
    return dev > 3 ? 'hi-IN' : 'en-US';
  }

  /// Markdown ke symbols hata kar bolne layak text banata hai.
  static String cleanForSpeech(String input) {
    var t = input;
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '. ');
    t = t.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );
    t = t.replaceAll(RegExp(r'https?://\S+'), '');
    t = t.replaceAll('`', '');
    t = t.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'[*_~>|]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > _maxSpeechChars) {
      t = t.substring(0, _maxSpeechChars);
    }
    return t;
  }

  // ---------- lifecycle ----------

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _onText = null;
    _onDone = null;
    _stt.cancel().catchError((_) {});
    _tts.stop().catchError((_) {});
    super.dispose();
  }
}
