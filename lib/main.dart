import 'dart:io';

import 'package:cardmind/bridge/frb_generated.dart';
import 'package:cardmind/bridge/api/device_config.dart'
    as device_config_api;
import 'package:cardmind/bridge/api/identity.dart'
    as identity_api;
import 'package:cardmind/providers/app_info_provider.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/providers/pool_provider.dart';
import 'package:cardmind/providers/settings_provider.dart';
import 'package:cardmind/providers/theme_provider.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge
  final externalLibrary = (Platform.isIOS || Platform.isMacOS)
      ? ExternalLibrary.process(iKnowHowToUseIt: true)
      : null;
  await RustLib.init(externalLibrary: externalLibrary);

  runApp(const CardMindApp());
}

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppInfoProvider()),
        ChangeNotifierProvider(create: (_) => PoolProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'CardMind',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Get application support directory (recommended for app data)
      final directory = await getApplicationSupportDirectory();
      final storagePath = directory.path;

      // Debug: Print paths
      debugPrint('=== CardMind Debug ===');
      debugPrint('Application support directory: ${directory.path}');
      debugPrint('Storage path: $storagePath');
      debugPrint('=====================');

      // Create storage directory if it doesn't exist
      final storageDir = Directory(storagePath);
      if (!storageDir.existsSync()) {
        storageDir.createSync(recursive: true);
        debugPrint('Created storage directory: $storagePath');
      } else {
        debugPrint('Storage directory exists: $storagePath');
      }

      if (!mounted) return;

      // Get providers before awaits
      final themeProvider = context.read<ThemeProvider>();
      final cardProvider = context.read<CardProvider>();
      final poolProvider = context.read<PoolProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      final appInfoProvider = context.read<AppInfoProvider>();

      // Initialize providers
      await themeProvider.initialize();
      if (!mounted) return;

      await settingsProvider.initialize();
      if (!mounted) return;

      await appInfoProvider.initialize();
      if (!mounted) return;

      await cardProvider.initialize(storagePath);
      if (!mounted) return;

      await poolProvider.initialize(storagePath);
      if (!mounted) return;

      // Initialize device config first (required by sync service)
      try {
        await device_config_api.initDeviceConfig(basePath: storagePath);
        debugPrint('Device config initialized successfully');
      } on Exception catch (e) {
        debugPrint('Warning: Failed to initialize device config: $e');
      }

      // Initialize identity manager (required for peer_id)
      try {
        identity_api.initIdentityManager(basePath: storagePath);
        debugPrint('Identity manager initialized successfully');
      } on Exception catch (e) {
        debugPrint('Warning: Failed to initialize identity manager: $e');
      }

      // Start sync service only when joined
      await poolProvider.startSyncServiceIfJoined();

      setState(() {
        _isInitializing = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing CardMind...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Initialization failed:\n$_error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _error = null;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
