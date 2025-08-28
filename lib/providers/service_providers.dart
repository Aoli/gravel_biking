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
/// Useful for showing loading states during app startup.
final routeServiceInitializedProvider = FutureProvider<bool>((ref) async {
  final routeService = ref.read(routeServiceProvider);
  await routeService.initialize();
  return true;
});
