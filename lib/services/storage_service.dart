import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Saves and loads the app's settings.
/// - The API key goes into the phone's secure storage (encrypted).
/// - Everything else goes into normal preferences.
/// The key is never printed or logged anywhere.
class StorageService {
  StorageService();

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------- API key (secure) ----------

  Future<String> getApiKey() async {
    try {
      return (await _secure.read(key: AppConstants.keyApiKey)) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setApiKey(String key) async {
    try {
      final clean = key.trim();
      if (clean.isEmpty) {
        await _secure.delete(key: AppConstants.keyApiKey);
      } else {
        await _secure.write(key: AppConstants.keyApiKey, value: clean);
      }
    } catch (_) {
      // Best-effort: the caller keeps the key in memory for this session.
    }
  }

  Future<void> deleteApiKey() async {
    try {
      await _secure.delete(key: AppConstants.keyApiKey);
    } catch (_) {}
  }

  // ---------- Normal settings ----------

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<String> getBaseUrl() async {
    final p = await _prefs();
    return p?.getString(AppConstants.keyBaseUrl) ?? AppConstants.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final p = await _prefs();
    await p?.setString(AppConstants.keyBaseUrl, url.trim());
  }

  Future<double> getFontScale() async {
    final p = await _prefs();
    final value = p?.getDouble(AppConstants.keyFontScale) ?? 1.0;
    return value.clamp(AppConstants.minFontScale, AppConstants.maxFontScale);
  }

  Future<void> setFontScale(double value) async {
    final p = await _prefs();
    await p?.setDouble(AppConstants.keyFontScale, value);
  }

  Future<bool> getHaptics() async {
    final p = await _prefs();
    return p?.getBool(AppConstants.keyHaptics) ?? true;
  }

  Future<void> setHaptics(bool value) async {
    final p = await _prefs();
    await p?.setBool(AppConstants.keyHaptics, value);
  }

  Future<bool> getAutoStart() async {
    final p = await _prefs();
    return p?.getBool(AppConstants.keyAutoStart) ?? true;
  }

  Future<void> setAutoStart(bool value) async {
    final p = await _prefs();
    await p?.setBool(AppConstants.keyAutoStart, value);
  }

  Future<String> getLastModel() async {
    final p = await _prefs();
    return p?.getString(AppConstants.keyLastModel) ?? AppConstants.autoModel;
  }

  Future<void> setLastModel(String modelId) async {
    final p = await _prefs();
    await p?.setString(AppConstants.keyLastModel, modelId);
  }
}
