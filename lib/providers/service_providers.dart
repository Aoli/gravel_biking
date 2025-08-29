import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/services/route_service.dart';
import 'package:gravel_biking/services/auth_service.dart';
import 'package:gravel_biking/services/file_service.dart';
import 'package:gravel_biking/services/firestore_route_service.dart';
import 'package:gravel_biking/services/firestore_user_service.dart';
import 'package:gravel_biking/services/synced_route_service.dart';
import 'package:gravel_biking/models/saved_route.dart';
import 'package:gravel_biking/models/user_profile.dart';
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

/// Provider for FileService instance
///
/// Creates and manages the FileService instance that handles
/// import/export operations for routes.
final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

/// Provider for FirestoreRouteService instance
///
/// Creates and manages the FirestoreRouteService instance that handles
/// route synchronization with Firestore.
final firestoreRouteServiceProvider = Provider<FirestoreRouteService>((ref) {
  return FirestoreRouteService();
});

/// Provider for SyncedRouteService instance
///
/// Creates the enhanced route service that syncs between local Hive storage
/// and Firestore. This service provides offline-first functionality with
/// cloud synchronization for authenticated users.
final syncedRouteServiceProvider = Provider<SyncedRouteService>((ref) {
  final localService = ref.read(routeServiceProvider);
  final cloudService = ref.read(firestoreRouteServiceProvider);
  final user = ref.watch(currentUserProvider);

  return SyncedRouteService(
    localService: localService,
    cloudService: cloudService,
    userId: user?.uid,
  );
});

/// Provider for all accessible routes using synced service
///
/// Returns combined local and cloud routes accessible to the current user.
/// This replaces the direct Firestore provider for better offline support.
final allAccessibleRoutesProvider = FutureProvider<List<SavedRoute>>((
  ref,
) async {
  // Ensure authentication is initialized
  await ref.watch(authInitializationProvider.future);

  final syncedService = ref.read(syncedRouteServiceProvider);
  try {
    return await syncedService.loadAllRoutes();
  } catch (e) {
    debugPrint('AllAccessibleRoutes: Failed to load routes: $e');
    return [];
  }
});

/// Provider for authentication initialization
///
/// Automatically initializes authentication when the app starts.
/// This ensures users are signed in before using Firestore features.
final authInitializationProvider = FutureProvider<void>((ref) async {
  final authService = ref.read(authServiceProvider);
  await authService.initialize();
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
/// Now handled by authInitializationProvider for better control.
final autoSignInProvider = FutureProvider<void>((ref) async {
  // Watch auth initialization to ensure it completes
  await ref.watch(authInitializationProvider.future);
});

/// Provider for Firestore routes (user's accessible routes)
///
/// Returns all routes accessible to the current user:
/// - User's own routes (both public and private)
/// - Other users' public routes
final firestoreRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  // Ensure authentication is initialized
  await ref.watch(authInitializationProvider.future);

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    debugPrint('FirestoreRoutes: No authenticated user, returning empty list');
    return [];
  }

  final firestoreService = ref.read(firestoreRouteServiceProvider);
  try {
    return await firestoreService.getAllAccessibleRoutes(user.uid);
  } catch (e) {
    debugPrint('FirestoreRoutes: Failed to load routes: $e');
    return [];
  }
});

/// Provider for public routes only
///
/// Returns only public routes from Firestore, accessible to all users.
final publicRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  final firestoreService = ref.read(firestoreRouteServiceProvider);
  try {
    return await firestoreService.getPublicRoutes();
  } catch (e) {
    debugPrint('PublicRoutes: Failed to load public routes: $e');
    return [];
  }
});

/// Provider for user's private routes only
///
/// Returns only the current user's private routes from Firestore.
final userPrivateRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  await ref.watch(authInitializationProvider.future);

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final firestoreService = ref.read(firestoreRouteServiceProvider);
  try {
    return await firestoreService.getUserRoutes(user.uid);
  } catch (e) {
    debugPrint('UserPrivateRoutes: Failed to load private routes: $e');
    return [];
  }
});

// =============================================================================
// STREAMING PROVIDERS - Real-time data updates
// =============================================================================

/// Provider for FirestoreUserService instance
final firestoreUserServiceProvider = Provider<FirestoreUserService>((ref) {
  return FirestoreUserService();
});

/// Stream provider for all accessible routes (real-time)
///
/// Combines user's routes and public routes from other users with real-time updates.
/// This replaces the static allAccessibleRoutesProvider for live data.
final streamAllAccessibleRoutesProvider = StreamProvider<List<SavedRoute>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final firestoreService = ref.read(firestoreRouteServiceProvider);

  // Combine user routes and public routes streams
  return firestoreService.streamUserRoutes(user.uid).asyncMap((
    userRoutes,
  ) async {
    try {
      // Get public routes from other users
      final publicRoutes = await firestoreService.getPublicRoutes();
      final otherUsersPublicRoutes = publicRoutes
          .where((route) => route.userId != user.uid)
          .toList();

      final allRoutes = [...userRoutes, ...otherUsersPublicRoutes];

      // Sort by save date (newest first)
      allRoutes.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      return allRoutes;
    } catch (e) {
      debugPrint('StreamAllAccessibleRoutes: Error combining routes: $e');
      return userRoutes; // Return at least user routes if public routes fail
    }
  });
});

/// Stream provider for user's routes (real-time)
final streamUserRoutesProvider = StreamProvider<List<SavedRoute>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final firestoreService = ref.read(firestoreRouteServiceProvider);
  return firestoreService.streamUserRoutes(user.uid);
});

/// Stream provider for public routes (real-time)
final streamPublicRoutesProvider = StreamProvider<List<SavedRoute>>((ref) {
  final firestoreService = ref.read(firestoreRouteServiceProvider);
  return firestoreService.streamPublicRoutes();
});

/// Stream provider for current user profile
final streamUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(null);
  }

  final userService = ref.read(firestoreUserServiceProvider);
  return userService.streamUserProfile(user.uid);
});

/// Provider for local saved routes
///
/// This provider loads routes from the local Hive storage.
/// For pure local storage without cloud sync.
final localSavedRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  final routeService = ref.read(routeServiceProvider);
  await ref.watch(routeServiceInitializedProvider.future);

  try {
    return await routeService.loadSavedRoutes();
  } catch (e) {
    debugPrint('LocalSavedRoutes: Failed to load routes: $e');
    return [];
  }
});

/// Provider for ensuring user profile exists
final ensureUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final userService = ref.read(firestoreUserServiceProvider);

  try {
    return await userService.createOrUpdateUser(
      user.uid,
      isAnonymous: user.isAnonymous,
    );
  } catch (e) {
    debugPrint('EnsureUserProfile: Failed to create/update user profile: $e');
    return null;
  }
});
