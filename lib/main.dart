import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/models_provider.dart';
import 'providers/settings_provider.dart';
import 'services/database_service.dart';
import 'services/voice_service.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-screen look: content draws behind the status and navigation bars.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Settings, theme aur saved chats first frame se pehle load karo.
  final themeProvider = ThemeProvider();
  final settingsProvider = SettingsProvider();
  final chatProvider = ChatProvider(settingsProvider, DatabaseService());
  await Future.wait([
    themeProvider.load(),
    settingsProvider.load(),
    chatProvider.load(), // database kholta hai aur chats padhta hai
  ]);

  final gatewayProvider = GatewayProvider(settingsProvider);
  final modelsProvider = ModelsProvider(settingsProvider);
  final voiceService = VoiceService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<GatewayProvider>.value(value: gatewayProvider),
        ChangeNotifierProvider<ModelsProvider>.value(value: modelsProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<VoiceService>.value(value: voiceService),
      ],
      child: const AiHubApp(),
    ),
  );
}
