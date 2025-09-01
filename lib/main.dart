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
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gravel_biking/screens/gravel_streets_map.dart';
import 'package:gravel_biking/services/storage_service.dart';
import 'package:gravel_biking/widgets/splash_screen.dart';
import 'firebase_options.dart';

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

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('App will continue without authentication features');
  }

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  void _onSplashFinished() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel First',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      // Provide a symbol/emoji fallback family for missing glyphs on some devices
      builder: (context, child) {
        // This call ensures the Google Fonts loader injects the family on web
        final symbolsFamily = GoogleFonts.notoSansSymbols2().fontFamily;
        return DefaultTextStyle.merge(
          style: TextStyle(
            fontFamilyFallback: symbolsFamily != null ? [symbolsFamily] : null,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _showSplash
          ? SplashScreen(onSplashFinished: _onSplashFinished)
          : const GravelStreetsMap(),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

    final text = GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.notoSans(
        textStyle: base.textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.titleSmall,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodyLarge,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodyMedium,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodySmall,
        fontWeight: FontWeight.w400,
      ),
    );

    return base.copyWith(textTheme: text);
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
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

    final text = GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.notoSans(
        textStyle: base.textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.titleSmall,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodyLarge,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodyMedium,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.notoSans(
        textStyle: base.textTheme.bodySmall,
        fontWeight: FontWeight.w400,
      ),
    );

    return base.copyWith(textTheme: text);
  }
}
