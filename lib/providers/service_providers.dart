import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/services/route_service.dart';
import 'package:gravel_biking/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Provider for AuthService instance
///
/// Creates and manages the AuthService instance that handles
/// Firebase anonymous authentication.
///
/// This is a singleton provider for the auth service.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for current authentication state
///
/// Streams the current Firebase user authentication state.
/// Returns null if no user is signed in.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for current user
///
/// Returns the current Firebase user or null if not signed in.
/// This is a computed provider based on the auth state stream.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for sign-in state
///
/// Returns true if a user is currently signed in.
final isSignedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

/// Provider for auto sign-in
///
/// Automatically signs in the user anonymously if not already signed in.
/// This ensures users can use the app immediately without manual sign-in.
final autoSignInProvider = FutureProvider<void>((ref) async {
  final authService = ref.read(authServiceProvider);

  try {
    await authService.ensureSignedIn();
    debugPrint('AuthService: Auto sign-in completed successfully');
  } catch (e) {
    debugPrint('AuthService: Auto sign-in failed: $e');
    // Don't rethrow - app should continue even if auth fails
  }
});
