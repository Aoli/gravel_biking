import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/services/route_service.dart';

/// Provider for RouteService instance
///
/// Creates and manages the RouteService instance that handles
/// saved routes storage using Hive.
///
/// This is a singleton provider that creates the service
/// but does NOT automatically initialize it to avoid race conditions.
/// Use routeServiceInitializedProvider to ensure proper initialization.
final routeServiceProvider = Provider<RouteService>((ref) {
  final routeService = RouteService();

  // Clean up when provider is disposed
  ref.onDispose(() {
    routeService.dispose();
  });

  return routeService;
});

/// Provider for RouteService initialization state
///
/// Tracks whether the RouteService has been successfully initialized.
/// Returns true if storage is working, false if storage is disabled but app should continue.
/// This allows graceful degradation in private browsing mode.
final routeServiceInitializedProvider = FutureProvider<bool>((ref) async {
  try {
    final routeService = ref.read(routeServiceProvider);
    await routeService.initialize();

    // Check if storage is actually available after initialization
    final storageAvailable = routeService.isStorageAvailable();
    if (!storageAvailable) {
      debugPrint(
        'RouteService: Storage disabled - app continues with limited functionality',
      );
    }

    return true; // Always return true - app should continue regardless of storage state
  } catch (e) {
    // This should not happen with the new graceful degradation, but keep as fallback
    debugPrint('RouteService initialization failed: $e');
    return true; // Still return true to allow app to continue
  }
});
