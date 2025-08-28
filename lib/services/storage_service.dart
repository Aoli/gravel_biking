import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_route.dart';

/// Centralized storage initialization service
///
/// Handles Hive database initialization with proper error handling
/// and prevents double initialization issues. Provides a single
/// point of truth for storage availability across the application.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  bool _isInitialized = false;
  bool _initializationFailed = false;
  String? _errorMessage;

  /// Check if storage is initialized and available
  bool get isInitialized => _isInitialized && !_initializationFailed;

  /// Check if initialization failed
  bool get hasInitializationError => _initializationFailed;

  /// Get error message if initialization failed
  String? get errorMessage => _errorMessage;

  /// Check if we're running in a test environment
  ///
  /// Tests can be detected by checking if flutter_test_config.dart has
  /// already initialized Hive, which indicates we're in a test runner.
  bool _isTestEnvironment() {
    try {
      // If Hive is already initialized, we're likely in a test environment
      // where flutter_test_config.dart has already set up Hive
      return Hive.isBoxOpen('test_detection') || _checkForTestAdapter();
    } catch (e) {
      // If checking throws an error, assume production environment
      return false;
    }
  }

  /// Helper method to detect test environment by checking adapter registration
  bool _checkForTestAdapter() {
    try {
      // If adapters are already registered, likely from test setup
      return Hive.isAdapterRegistered(0) || Hive.isAdapterRegistered(1);
    } catch (e) {
      return false;
    }
  }

  /// Initialize Hive storage system
  ///
  /// This should be called only once during app startup.
  /// Subsequent calls will return immediately if already initialized.
  Future<bool> initialize() async {
    // Prevent double initialization
    if (_isInitialized) {
      debugPrint('StorageService: Already initialized, skipping');
      return !_initializationFailed;
    }

    debugPrint('StorageService: Starting initialization...');

    try {
      // Initialize Hive - use different methods for test vs production
      if (kDebugMode && !kIsWeb && _isTestEnvironment()) {
        // In test environment, Hive is already initialized by flutter_test_config.dart
        debugPrint(
          'StorageService: Test environment detected, skipping Hive initialization',
        );
      } else {
        // Production environment - use full Flutter initialization
        await Hive.initFlutter();
        debugPrint('StorageService: Hive.initFlutter() completed');
      }

      // Register adapters (only if not already registered)
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SavedRouteAdapter());
        debugPrint('StorageService: SavedRouteAdapter registered');
      } else {
        debugPrint('StorageService: SavedRouteAdapter already registered');
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(LatLngDataAdapter());
        debugPrint('StorageService: LatLngDataAdapter registered');
      } else {
        debugPrint('StorageService: LatLngDataAdapter already registered');
      }

      _isInitialized = true;
      _initializationFailed = false;
      _errorMessage = null;

      debugPrint('✅ StorageService: Initialization successful');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StorageService: Initialization failed: $e');
      debugPrint('StorageService: Stack trace: $stackTrace');

      _isInitialized = false;
      _initializationFailed = true;
      _errorMessage = e.toString();

      // Enhanced web environment debugging
      if (kIsWeb) {
        debugPrint('🌐 StorageService: Web environment error details:');
        debugPrint('  - Error type: ${e.runtimeType}');
        debugPrint('  - Check browser storage permissions');
        debugPrint('  - Try clearing browser data if issues persist');
        debugPrint('  - Test in incognito mode');
      }

      return false;
    }
  }

  /// Get diagnostic information about storage state
  String getDiagnostics() {
    final diagnostics = StringBuffer();
    diagnostics.writeln('StorageService State:');
    diagnostics.writeln('  initialized: $_isInitialized');
    diagnostics.writeln('  failed: $_initializationFailed');
    diagnostics.writeln('  error: ${_errorMessage ?? 'None'}');
    diagnostics.writeln('  platform: ${kIsWeb ? 'Web' : 'Native'}');

    if (_initializationFailed && kIsWeb) {
      diagnostics.writeln('Web Troubleshooting:');
      diagnostics.writeln('  1. Clear browser cache and storage');
      diagnostics.writeln('  2. Check if in private/incognito mode');
      diagnostics.writeln('  3. Verify storage permissions');
      diagnostics.writeln('  4. Try different browser');
    }

    return diagnostics.toString();
  }

  /// Reset initialization state (for testing purposes)
  void reset() {
    _isInitialized = false;
    _initializationFailed = false;
    _errorMessage = null;
    debugPrint('StorageService: State reset');
  }
}
