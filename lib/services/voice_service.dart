import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
///
/// Mic ab tab tak chalta rehta hai jab tak user khud band na kare.
/// [onText] ko HAMESHA poora text milta hai (ab tak ka sab kuch jod kar).
/// isFinal sirf tab true aata hai jab mic band ho jata hai.
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _disposed = false;

  bool _listening = false; // user ke hisaab se mic chalu hai
  bool _wantListening = false; // user ne band nahi kiya, to dobara chalu karte raho
  bool _speaking = false;
  double _level = 0;
  String? _error;
  String? _speakingId;
  String? _localeId; // null = auto
  String? _ttsLang;

  // Ab tak ka text.
  String _committed = ''; // pakka ho chuka text (pichhle sessions ka)
  String _current = ''; // abhi chal rahe session ka text

  // Dobara chalu karne ka hisaab.
  bool _restartScheduled = false;
  DateTime _sessionStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<DateTime> _restartTimes = [];

  void Function(String text, bool isFinal)? _onText;
  VoidCallback? _onDone;

  static const int _maxSpeechChars = 3900;
  static const String _prefsLocaleKey = 'voice_locale';

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

  /// Abhi chuni hui bhasha, jaise 'hi_IN'. Null = auto.
  String? get localeId => _localeId;

  /// Is message ko abhi bola ja raha hai?
  bool isSpeakingId(String id) => _speaking && _speakingId == id;

  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  /// Bolne ki bhasha badlo, jaise 'hi_IN' ya 'en_IN'. null = auto.
  /// Chuni hui bhasha phone mein yaad rehti hai.
  void setLocale(String? localeId) {
    _localeId = localeId;
    _saveLocale(localeId);
  }

  /// Phone mein jitni bhashayein sunne ke liye maujood hain unki list.
  Future<List<LocaleName>> availableLocales() async {
    final ok = await _initStt();
    if (!ok) return const [];
    try {
      return await _stt.locales();
    } catch (e) {
      debugPrint('VoiceService locales error: $e');
      return const [];
    }
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

  Future<void> _saveLocale(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_prefsLocaleKey);
      } else {
        await prefs.setString(_prefsLocaleKey, id);
      }
    } catch (_) {}
  }

  Future<String?> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsLocaleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickLocale() async {
    if (_localeId != null) return;

    // 1) User ne pehle jo bhasha chuni thi.
    final saved = await _loadSavedLocale();
    if (saved != null && saved.isNotEmpty) {
      _localeId = saved;
      return;
    }

    // 2) Warna Hindi (hi_IN), agar phone mein mile.
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
  /// Ye tab tak sunta rehta hai jab tak [stopListening] na bulao.
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
    _committed = '';
    _current = '';
    _restartTimes.clear();
    _restartScheduled = false;
    _wantListening = true;
    _listening = true;
    _level = 0;
    _safeNotify();

    final started = await _beginSession();
    if (!started) {
      _wantListening = false;
      _listening = false;
      _level = 0;
      _onText = null;
      _onDone = null;
      _error ??= 'Voice input shuru nahi ho paya.';
      _safeNotify();
      return false;
    }
    return true;
  }

  /// Ek sunne ka session shuru karta hai (Android jab band kare to dobara bulaya jata hai).
  Future<bool> _beginSession() async {
    _current = '';
    _sessionStartedAt = DateTime.now();
    try {
      await _stt.listen(
        onResult: _handleResult,
        // Lambe samay tak chalne do. Beech mein Android band kare to hum dobara chalu karte hain.
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(minutes: 2),
        localeId: _localeId,
        onSoundLevelChange: _handleLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('VoiceService listen error: $e');
      _error = 'Voice input shuru nahi ho paya.';
      return false;
    }
  }

  /// Mic band karo (jo bola gaya wo final text mein aa jata hai).
  Future<void> stopListening() async {
    if (!_listening) return;
    _wantListening = false; // ab dobara chalu mat karna
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
    }
    // Aakhri bole hue shabd aane ka thoda samay do.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _completeStop();
  }

  /// Mic band karo aur jo suna wo phenk do.
  Future<void> cancelListening() async {
    _onText = null;
    _wantListening = false;
    if (!_listening) return;
    try {
      await _stt.cancel();
    } catch (e) {
      debugPrint('VoiceService cancel error: $e');
    }
    _committed = '';
    _current = '';
    _listening = false;
    _level = 0;
    _safeNotify();
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  // ---------- text jodna ----------

  String _join(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    if (x.isEmpty) return y;
    if (y.isEmpty) return x;
    return '$x $y';
  }

  /// Abhi ke session ka text pakka karke jama kar do.
  void _commitCurrent() {
    if (_current.trim().isEmpty) {
      _current = '';
      return;
    }
    _committed = _join(_committed, _current);
    _current = '';
  }

  void _emit() {
    _onText?.call(_join(_committed, _current), false);
  }

  // ---------- speech ke events ----------

  void _handleResult(SpeechRecognitionResult r) {
    if (!_listening) return;
    _current = r.recognizedWords;
    if (_current.trim().isNotEmpty) _restartTimes.clear();
    if (r.finalResult) _commitCurrent();
    _emit();
  }

  void _handleLevel(double level) {
    // Android par level lagbhag -2 se 10 tak aata hai.
    final n = ((level + 2) / 12).clamp(0.0, 1.0).toDouble();
    if ((n - _level).abs() < 0.05) return;
    _level = n;
    _safeNotify();
  }

  void _handleStatus(String status) {
    if (status != 'notListening' && status != 'done') return;
    // Naya session shuru hone ke turant baad aane wale purane events ko andekha karo.
    if (DateTime.now().difference(_sessionStartedAt) <
        const Duration(milliseconds: 700)) {
      return;
    }
    _onSessionEnded();
  }

  void _handleError(SpeechRecognitionError e) {
    final msg = e.errorMsg;

    // Chup rehne par aane wale errors: mic chalu rakho aur dobara suno.
    final quiet = msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('timeout') ||
        msg.contains('busy');
    if (_wantListening && quiet) {
      _onSessionEnded();
      return;
    }

    if (msg.contains('permission')) {
      _error = 'Mic permission nahi hai. Phone Settings mein allow karo.';
    } else if (msg.contains('network')) {
      _error = 'Internet nahi hai ya kamzor hai. Voice ke liye internet chahiye.';
    } else if (msg.contains('language')) {
      _error = 'Ye bhasha is phone par sunne ke liye available nahi hai.';
    } else if (msg.contains('no_match') || msg.contains('timeout')) {
      _error = 'Kuch sunai nahi diya. Dobara bolo.';
    } else {
      _error = 'Voice input mein dikkat: $msg';
    }
    _wantListening = false;
    _completeStop();
  }

  /// Android ne ek session band kiya. User ne band nahi kiya to dobara chalu karo.
  void _onSessionEnded() {
    if (!_listening) return;
    _commitCurrent();
    _emit();
    if (_wantListening) {
      _scheduleRestart();
    } else {
      _completeStop();
    }
  }

  void _scheduleRestart() {
    if (_restartScheduled) return;
    _restartScheduled = true;

    // Agar bahut jaldi-jaldi bina kuch sune fail ho raha ho to ruk jao.
    final now = DateTime.now();
    _restartTimes.removeWhere((t) => now.difference(t) > const Duration(seconds: 8));
    if (_restartTimes.length >= 6) {
      _restartScheduled = false;
      _error = 'Mic baar-baar band ho raha hai. Phone ki Google voice service '
          'aur internet check karo.';
      _wantListening = false;
      _completeStop();
      return;
    }
    _restartTimes.add(now);

    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      _restartScheduled = false;
      if (!_listening || !_wantListening || _disposed) return;
      try {
        if (_stt.isListening) await _stt.cancel();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!_listening || !_wantListening || _disposed) return;

      final ok = await _beginSession();
      if (!ok) {
        _wantListening = false;
        _completeStop();
      }
    });
  }

  /// Mic sach mein band ho gaya: final text bhejo aur UI ko batao.
  void _completeStop() {
    if (!_listening) return;
    _commitCurrent();
    _wantListening = false;
    _listening = false;
    _level = 0;
    _safeNotify();

    final text = _committed;
    if (text.trim().isNotEmpty) {
      _onText?.call(text, true);
    }
    _onText = null;

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
    _wantListening = false;
    _onText = null;
    _onDone = null;
    _stt.cancel().catchError((_) {});
    _tts.stop().catchError((_) {});
    super.dispose();
  }
}
