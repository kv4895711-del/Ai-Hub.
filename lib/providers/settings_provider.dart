import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../services/storage_service.dart';

/// Holds the app's settings (gateway address, API key, font size, haptics...)
/// and saves every change. Other providers read the key and address from here.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;

  String _apiKey = '';
  String _baseUrl = AppConstants.defaultBaseUrl;
  double _fontScale = 1.0;
  bool _haptics = true;
  bool _autoStart = true;
  String _lastModel = AppConstants.autoModel;
  bool _loaded = false;

  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  double get fontScale => _fontScale;
  bool get haptics => _haptics;
  bool get autoStart => _autoStart;
  String get lastModel => _lastModel;
  bool get loaded => _loaded;

  /// True when a key has been entered.
  bool get hasKey => _apiKey.trim().isNotEmpty;

  // ---------- Load ----------

  Future<void> load() async {
    _apiKey = await _storage.getApiKey();
    _baseUrl = await _storage.getBaseUrl();
    _fontScale = await _storage.getFontScale();
    _haptics = await _storage.getHaptics();
    _autoStart = await _storage.getAutoStart();
    _lastModel = await _storage.getLastModel();
    _loaded = true;
    notifyListeners();
  }

  // ---------- Changes ----------

  Future<void> setApiKey(String value) async {
    _apiKey = value.trim();
    notifyListeners();
    await _storage.setApiKey(_apiKey);
  }

  Future<void> setBaseUrl(String value) async {
    var clean = value.trim();
    if (clean.isEmpty) clean = AppConstants.defaultBaseUrl;
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _baseUrl = clean;
    notifyListeners();
    await _storage.setBaseUrl(_baseUrl);
  }

  Future<void> resetBaseUrl() => setBaseUrl(AppConstants.defaultBaseUrl);

  Future<void> setFontScale(double value) async {
    _fontScale = value.clamp(AppConstants.minFontScale, AppConstants.maxFontScale);
    notifyListeners();
    await _storage.setFontScale(_fontScale);
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    notifyListeners();
    await _storage.setHaptics(value);
  }

  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    await _storage.setAutoStart(value);
  }

  Future<void> setLastModel(String modelId) async {
    if (_lastModel == modelId) return;
    _lastModel = modelId;
    notifyListeners();
    await _storage.setLastModel(modelId);
  }
}
