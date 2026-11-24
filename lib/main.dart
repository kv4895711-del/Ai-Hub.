import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/settings_provider.dart';
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

  // Load saved settings and theme before the first frame.
  final themeProvider = ThemeProvider();
  final settingsProvider = SettingsProvider();
  await Future.wait([themeProvider.load(), settingsProvider.load()]);

  final gatewayProvider = GatewayProvider(settingsProvider);
  final chatProvider = ChatProvider(settingsProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<GatewayProvider>.value(value: gatewayProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ],
      child: const AiHubApp(),
    ),
  );
}
