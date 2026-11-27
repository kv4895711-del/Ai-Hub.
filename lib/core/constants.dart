/// App-wide constants. Change the app name here and it changes everywhere.
class AppConstants {
  AppConstants._();

  // ---- Identity ----
  static const String appName = 'Orbit';
  static const String appTagline = 'Many AI models. One app.';

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

  // Theme
  static const String keyThemeMode = 'theme_mode';
  static const String keyPresetId = 'theme_preset';
  static const String keyCustomAccent = 'theme_custom_accent';
  static const String keyThemePalette = 'theme_palette'; // up to 4 colors
  static const String keyWallpaperType = 'wallpaper_type'; // none | builtin | gallery
  static const String keyWallpaperRef = 'wallpaper_ref'; // built-in id or file path
  static const String keyWallpaperDim = 'wallpaper_dim'; // 0.0 to 0.8

  // First-time setup
  static const String keySetupDone = 'setup_done';
  static const String keySetupHintHidden = 'setup_hint_hidden';

  // Profile (kept only on this phone)
  static const String keyProfileName = 'profile_name';
  static const String keyProfilePhoto = 'profile_photo';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyPinHash = 'pin_hash';

  // ---- Chat ----
  static const String newChatTitle = 'New chat';
  static const int maxTitleLength = 40;
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.4;

  // ---- Theme limits ----
  static const int maxPaletteColors = 4;
  static const double maxWallpaperDim = 0.8;

  // ---- Example prompts shown on an empty chat ----
  static const List<String> examplePrompts = [
    'Explain how a rainbow forms, in simple words',
    'Write a short, friendly email asking for a day off',
    'Give me a 3-day study plan for learning Flutter',
    'Suggest 5 creative names for a tools app',
  ];
}
