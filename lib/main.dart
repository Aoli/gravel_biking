/// Gravel First - Flutter application entry point
///
/// Cross-platform gravel biking route planning app with interactive maps.
/// Displays gravel roads from OpenStreetMap and provides tools for measuring
/// custom routes with import/export capabilities.
///
/// Key features:
/// - Interactive map with gravel road overlay
/// - Route measurement and editing tools
/// - GPX and GeoJSON import/export
/// - Persistent route storage with Hive
/// - Riverpod state management
///
/// Platform support:
/// - Web (primary target with PWA capabilities)
/// - Android and iOS (future native app development)
/// - Desktop platforms (Windows, macOS, Linux)
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/screens/gravel_streets_map.dart';
import 'package:gravel_biking/services/storage_service.dart';

/// Application entry point with centralized storage initialization
///
/// Initializes the Flutter framework and sets up storage using the centralized
/// StorageService. Implements graceful degradation if storage fails,
/// particularly important for web environments with restricted storage access.
///
/// The app continues to function even if storage initialization fails, providing
/// core functionality without persistent route storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage through the centralized service
  final storageService = StorageService();
  final storageInitialized = await storageService.initialize();

  if (storageInitialized) {
    debugPrint('✅ Storage initialized successfully in main()');
  } else {
    debugPrint(
      '❌ Storage initialization failed, continuing with graceful degradation',
    );
    debugPrint('Error: ${storageService.errorMessage}');

    // Log diagnostics for troubleshooting
    final diagnostics = storageService.getDiagnostics();
    for (final line in diagnostics.split('\n')) {
      if (line.trim().isNotEmpty) {
        debugPrint('  $line');
      }
    }
  }

  runApp(
    // ProviderScope enables Riverpod state management throughout the app
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel First',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const GravelStreetsMap(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shadowColor: Colors.black26,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      iconTheme: IconThemeData(
        applyTextScaling: false,
        size: 24,
        color: kIsWeb ? Colors.black87 : null,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shadowColor: Colors.black54,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(elevation: 1, shadowColor: Colors.black54),
      ),
      iconTheme: IconThemeData(
        applyTextScaling: false,
        size: 24,
        color: kIsWeb ? Colors.white : null,
      ),
    );
  }
}
