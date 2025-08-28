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
import 'package:gravel_biking/models/saved_route.dart';
import 'package:gravel_biking/screens/gravel_streets_map.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Application entry point with database initialization
///
/// Initializes the Flutter framework and sets up Hive database with type adapters
/// for persistent route storage. Implements graceful degradation if storage fails,
/// particularly important for web environments with restricted storage access.
///
/// The app continues to function even if Hive initialization fails, providing
/// core functionality without persistent storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive with enhanced error handling for web environments
    await Hive.initFlutter();

    // Register adapters AFTER initializing Hive (only once here)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SavedRouteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LatLngDataAdapter());
    }

    debugPrint('✅ Hive initialized successfully in main()');
  } catch (e, stackTrace) {
    debugPrint('❌ CRITICAL: Hive initialization failed in main(): $e');
    debugPrint('Stack trace: $stackTrace');

    // Enhanced mobile Chrome debugging
    if (kIsWeb) {
      debugPrint('🌐 Web environment detected');
      debugPrint('  - Storage initialization failed in web environment');
      debugPrint('  - Check browser storage permissions');
      debugPrint('  - Try clearing browser data if issues persist');
      debugPrint('  - Use incognito mode for testing');
    }

    // Continue app startup even if Hive fails - better user experience
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
