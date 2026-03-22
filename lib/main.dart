import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'models/server_config.dart';
import 'services/dufs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: frameless window (not available on mobile)
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(420, 740),
      minimumSize: Size(360, 600),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final config = await ServerConfig.load();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DufsService(),
      child: InoutApp(config: config),
    ),
  );
}

class InoutApp extends StatefulWidget {
  final ServerConfig config;
  const InoutApp({super.key, required this.config});

  @override
  State<InoutApp> createState() => _InoutAppState();
}

class _InoutAppState extends State<InoutApp> {
  late ThemeMode _themeMode;
  late String _colorScheme;
  late bool _setupDone;

  @override
  void initState() {
    super.initState();
    _themeMode = _themeModeFromString(widget.config.themeMode);
    _colorScheme = widget.config.colorScheme;
    _setupDone = widget.config.setupDone;
  }

  ThemeMode _themeModeFromString(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  void _onThemeChanged(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
      widget.config.themeMode = mode.name;
    });
  }

  void _onColorChanged(String scheme) {
    setState(() {
      _colorScheme = scheme;
      widget.config.colorScheme = scheme;
    });
  }

  void _onSetupDone() {
    setState(() {
      _setupDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return App(
      config: widget.config,
      themeMode: _themeMode,
      colorScheme: _colorScheme,
      setupDone: _setupDone,
      onThemeModeChanged: _onThemeChanged,
      onColorChanged: _onColorChanged,
      onSetupDone: _onSetupDone,
    );
  }
}
