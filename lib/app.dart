import 'package:flutter/material.dart';
import 'models/server_config.dart';
import 'pages/home_page.dart';
import 'pages/setup_wizard_page.dart';
import 'pages/splash_page.dart';

const appVersion = '0.2.2';

const Map<String, Color> presetColors = {
  'coral': Color(0xFFFF6B5A),
  'teal': Color(0xFF00BFA6),
  'violet': Color(0xFF7C4DFF),
  'ocean': Color(0xFF448AFF),
  'sunset': Color(0xFFFF8A65),
  'forest': Color(0xFF66BB6A),
};

class App extends StatelessWidget {
  final ServerConfig config;
  final ThemeMode themeMode;
  final String colorScheme;
  final bool setupDone;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onSetupDone;
  final VoidCallback? onCloseRequested;
  final GlobalKey<NavigatorState>? navigatorKey;

  const App({
    super.key,
    required this.config,
    required this.themeMode,
    required this.colorScheme,
    required this.setupDone,
    required this.onThemeModeChanged,
    required this.onColorChanged,
    required this.onSetupDone,
    this.onCloseRequested,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    final seedColor = presetColors[colorScheme] ?? const Color(0xFFFF6B5A);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'inout',
      debugShowCheckedModeBanner: false,
      locale: _localeFromCode(config.language),
      themeMode: themeMode,
      theme: _buildTheme(
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
      ),
      darkTheme: _buildTheme(
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
      ),
      home: SplashPage(
        child: setupDone
            ? HomePage(
                config: config,
                themeMode: themeMode,
                onThemeModeChanged: onThemeModeChanged,
                onColorChanged: onColorChanged,
                onCloseRequested: onCloseRequested,
              )
            : SetupWizardPage(
                config: config,
                onThemeModeChanged: onThemeModeChanged,
                onColorChanged: onColorChanged,
                onSetupDone: onSetupDone,
              ),
      ),
    );
  }

  ThemeData _buildTheme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(),
      ),
    );
  }

  Locale _localeFromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'zhTW':
        return const Locale('zh', 'TW');
      default:
        return const Locale('zh');
    }
  }
}
