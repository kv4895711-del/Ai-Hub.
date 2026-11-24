import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

/// Root widget: builds the MaterialApp with the user's chosen theme and font size.
class AiHubApp extends StatelessWidget {
  const AiHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final fontScale = context.select<SettingsProvider, double>((s) => s.fontScale);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: AppTheme.build(brightness: Brightness.light, accent: theme.accent),
      darkTheme: AppTheme.build(brightness: Brightness.dark, accent: theme.accent),
      builder: (context, child) {
        // Apply the font size from Settings and give every list an iOS-like bounce.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: ScrollConfiguration(
            behavior: const _BouncyScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class _BouncyScrollBehavior extends MaterialScrollBehavior {
  const _BouncyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
