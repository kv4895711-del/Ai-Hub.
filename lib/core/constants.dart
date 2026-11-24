/// App-wide constants. Change the app name here and it changes everywhere.
class AppConstants {
  AppConstants._();

  // ---- Identity ----
  static const String appName = 'AI Hub';
  static const String appTagline = 'All your free AI models, one app';

  // ---- Gateway (FreeLLMAPI running in Termux) ----
  static const String gatewayRoot = 'http://localhost:3001';
  static const String defaultBaseUrl = 'http://localhost:3001/v1';
  static const String autoModel = 'auto';

  // ---- Termux bridge (see tools/MainActivity.kt) ----
  static const String termuxChannel = 'com.aihub/termux';
  static const String termuxScript = 'startgateway.sh';
  static const int startupWaitSeconds = 40;
  static const int healthCheckSeconds = 3;

  // ---- Network ----
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration replyTimeout = Duration(minutes: 3);

  // ---- Saved-settings keys ----
  static const String keyApiKey = 'api_key';
  static const String keyBaseUrl = 'base_url';
  static const String keyFontScale = 'font_scale';
  static const String keyHaptics = 'haptics';
  static const String keyAutoStart = 'auto_start_gateway';
  static const String keyLastModel = 'last_model';
  static const String keyThemeMode = 'theme_mode';
  static const String keyPresetId = 'theme_preset';
  static const String keyCustomAccent = 'theme_custom_accent';

  // ---- Chat ----
  static const String newChatTitle = 'New chat';
  static const int maxTitleLength = 40;
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.4;

  // ---- Example prompts shown on an empty chat ----
  static const List<String> examplePrompts = [
    'Explain how a rainbow forms, in simple words',
    'Write a short, friendly email asking for a day off',
    'Give me a 3-day study plan for learning Flutter',
    'Suggest 5 creative names for a tools app',
  ];
}
