import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/services/route_service.dart';

/// Provider for RouteService instance
/// 
/// Creates and manages the RouteService instance that handles
/// saved routes storage using Hive.
/// 
/// This is a singleton provider that initializes the service
/// and keeps it available throughout the app lifecycle.
final routeServiceProvider = Provider<RouteService>((ref) {
  final routeService = RouteService();
  
  // Initialize the service when first accessed
  routeService.initialize();
  
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
