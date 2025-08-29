import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import 'route_service.dart';
import 'firestore_route_service.dart';

/// Enhanced route service that syncs between local Hive storage and Firestore
///
/// Provides offline-first functionality with cloud synchronization:
/// - Local storage with Hive for offline access
/// - Firestore sync for cloud backup and sharing
/// - Public/private visibility controls
/// - Automatic authentication handling
class SyncedRouteService {
  static const String _logPrefix = 'SyncedRouteService:';

  final RouteService _localService;
  final FirestoreRouteService _cloudService;
  final String? _userId;

  SyncedRouteService({
    required RouteService localService,
    required FirestoreRouteService cloudService,
    required String? userId,
  }) : _localService = localService,
       _cloudService = cloudService,
       _userId = userId;

  /// Save route with cloud sync
  ///
  /// Saves to local storage first, then syncs to Firestore if authenticated.
  /// Routes are private by default unless explicitly made public.
  Future<SavedRoute> saveCurrentRoute({
    required String name,
    required List<LatLng> routePoints,
    required bool loopClosed,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Saving route: "$name" (public: $isPublic)');
      }

      // Save to local storage first (offline-first approach)
      final localRoute = await _localService.saveCurrentRoute(
        name: name,
        routePoints: routePoints,
        loopClosed: loopClosed,
        description: description,
      );

      // If authenticated, also save to Firestore
      if (_userId != null) {
        try {
          final cloudRoute = SavedRoute.fromLatLng(
            name: name,
            latLngPoints: routePoints,
            loopClosed: loopClosed,
            savedAt: localRoute.savedAt,
            description: description,
            distance: localRoute.distance,
            isPublic: isPublic,
            userId: _userId,
          );

          final syncedRoute = await _cloudService.saveRoute(cloudRoute);

          if (kDebugMode) {
            print(
              '$_logPrefix ✅ Route synced to cloud: ${syncedRoute.firestoreId}',
            );
          }

          return syncedRoute;
        } catch (cloudError) {
          if (kDebugMode) {
            print('$_logPrefix ⚠️ Cloud sync failed: $cloudError');
            print('$_logPrefix Route saved locally only');
          }
          // Return local route even if cloud sync fails
          return localRoute;
        }
      } else {
        if (kDebugMode) {
          print('$_logPrefix No user authenticated - route saved locally only');
        }
        return localRoute;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to save route: $e');
      }
      rethrow;
    }
  }

  /// Load all accessible routes (local + cloud)
  ///
  /// Returns combined list of:
  /// - Local routes from Hive
  /// - User's cloud routes (if authenticated)
  /// - Public routes from other users
  Future<List<SavedRoute>> loadAllRoutes() async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading all accessible routes...');
      }

      // Always load local routes
      final localRoutes = await _localService.loadSavedRoutes();

      // If authenticated, also load cloud routes
      List<SavedRoute> cloudRoutes = [];
      if (_userId != null) {
        try {
          cloudRoutes = await _cloudService.getAllAccessibleRoutes(_userId);
          if (kDebugMode) {
            print('$_logPrefix Loaded ${cloudRoutes.length} routes from cloud');
          }
        } catch (cloudError) {
          if (kDebugMode) {
            print('$_logPrefix ⚠️ Failed to load cloud routes: $cloudError');
          }
        }
      }

      // Merge and deduplicate routes
      final allRoutes = <SavedRoute>[];

      // Add local routes
      allRoutes.addAll(localRoutes);

      // Add cloud routes that aren't already in local storage
      for (final cloudRoute in cloudRoutes) {
        final isDuplicate = localRoutes.any(
          (localRoute) =>
              cloudRoute.firestoreId != null &&
              localRoute.name == cloudRoute.name &&
              localRoute.savedAt
                      .difference(cloudRoute.savedAt)
                      .abs()
                      .inMinutes <
                  1,
        );

        if (!isDuplicate) {
          allRoutes.add(cloudRoute);
        }
      }

      // Sort by save date (newest first)
      allRoutes.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      if (kDebugMode) {
        print(
          '$_logPrefix ✅ Total accessible routes: ${allRoutes.length} (${localRoutes.length} local, ${cloudRoutes.length} cloud)',
        );
      }

      return allRoutes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load routes: $e');
      }
      // Fallback to local routes only
      return await _localService.loadSavedRoutes();
    }
  }

  /// Load only public routes from the cloud
  Future<List<SavedRoute>> loadPublicRoutes() async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading public routes...');
      }

      final publicRoutes = await _cloudService.getPublicRoutes();

      if (kDebugMode) {
        print('$_logPrefix ✅ Loaded ${publicRoutes.length} public routes');
      }

      return publicRoutes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load public routes: $e');
      }
      return [];
    }
  }

  /// Load only user's private routes from the cloud
  Future<List<SavedRoute>> loadPrivateRoutes() async {
    if (_userId == null) {
      if (kDebugMode) {
        print(
          '$_logPrefix No authenticated user - returning empty private routes',
        );
      }
      return [];
    }

    try {
      if (kDebugMode) {
        print('$_logPrefix Loading private routes for user: $_userId');
      }

      final privateRoutes = await _cloudService.getUserRoutes(_userId);

      if (kDebugMode) {
        print('$_logPrefix ✅ Loaded ${privateRoutes.length} private routes');
      }

      return privateRoutes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load private routes: $e');
      }
      return [];
    }
  }

  /// Update route visibility (public/private)
  Future<void> updateRouteVisibility(SavedRoute route, bool isPublic) async {
    if (_userId == null || route.firestoreId == null) {
      if (kDebugMode) {
        print(
          '$_logPrefix Cannot update visibility - no authentication or Firestore ID',
        );
      }
      throw Exception(
        'Route visibility can only be changed for authenticated users with synced routes',
      );
    }

    try {
      if (kDebugMode) {
        print(
          '$_logPrefix Updating route visibility: ${route.name} -> ${isPublic ? "public" : "private"}',
        );
      }

      await _cloudService.updateRouteVisibility(route.firestoreId!, isPublic);

      if (kDebugMode) {
        print('$_logPrefix ✅ Route visibility updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to update route visibility: $e');
      }
      rethrow;
    }
  }

  /// Delete route from both local and cloud storage
  Future<void> deleteRoute(SavedRoute route) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Deleting route: ${route.name}');
      }

      // Delete from local storage if it exists there
      try {
        await _localService.deleteRouteObject(route);
        if (kDebugMode) {
          print('$_logPrefix ✅ Route deleted from local storage');
        }
      } catch (localError) {
        if (kDebugMode) {
          print(
            '$_logPrefix ⚠️ Failed to delete from local storage: $localError',
          );
        }
      }

      // Delete from cloud storage if it exists there
      if (route.firestoreId != null) {
        try {
          await _cloudService.deleteRoute(route.firestoreId!);
          if (kDebugMode) {
            print('$_logPrefix ✅ Route deleted from cloud storage');
          }
        } catch (cloudError) {
          if (kDebugMode) {
            print(
              '$_logPrefix ⚠️ Failed to delete from cloud storage: $cloudError',
            );
          }
        }
      }

      if (kDebugMode) {
        print('$_logPrefix ✅ Route deletion completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to delete route: $e');
      }
      rethrow;
    }
  }

  /// Search routes across local and cloud storage
  Future<List<SavedRoute>> searchRoutes(String query) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Searching routes for: "$query"');
      }

      // Search local routes
      final localResults = await _localService.searchRoutes(query);

      // Search public routes in cloud
      List<SavedRoute> cloudResults = [];
      try {
        cloudResults = await _cloudService.searchPublicRoutes(query);
      } catch (cloudError) {
        if (kDebugMode) {
          print('$_logPrefix ⚠️ Cloud search failed: $cloudError');
        }
      }

      // Merge and deduplicate results
      final allResults = <SavedRoute>[];
      allResults.addAll(localResults);

      for (final cloudResult in cloudResults) {
        final isDuplicate = localResults.any(
          (localResult) =>
              cloudResult.firestoreId != null &&
              localResult.name == cloudResult.name &&
              localResult.savedAt
                      .difference(cloudResult.savedAt)
                      .abs()
                      .inMinutes <
                  1,
        );

        if (!isDuplicate) {
          allResults.add(cloudResult);
        }
      }

      // Sort by relevance/date
      allResults.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      if (kDebugMode) {
        print(
          '$_logPrefix ✅ Search completed: ${allResults.length} results (${localResults.length} local, ${cloudResults.length} cloud)',
        );
      }

      return allResults;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Search failed: $e');
      }
      // Fallback to local search only
      return await _localService.searchRoutes(query);
    }
  }

  /// Check if local storage is available
  bool isLocalStorageAvailable() => _localService.isStorageAvailable();

  /// Check if user is authenticated for cloud features
  bool isCloudSyncAvailable() => _userId != null;

  /// Get storage diagnostics
  String getStorageDiagnostics() {
    final local = _localService.getStorageDiagnostics();
    final cloud = isCloudSyncAvailable()
        ? 'Cloud sync: Available'
        : 'Cloud sync: Not authenticated';
    return '$local\n$cloud';
  }

  /// Find an existing route by name (case-insensitive)
  ///
  /// Returns the first route found with matching name, or null if none exists.
  /// Checks both local and cloud routes.
  Future<SavedRoute?> findRouteByName(String name) async {
    try {
      final allRoutes = await loadAllRoutes();
      final normalizedName = name.toLowerCase().trim();

      return allRoutes
          .where((route) => route.name.toLowerCase().trim() == normalizedName)
          .firstOrNull;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to find route by name: $e');
      }
      return null;
    }
  }

  /// Overwrite an existing route with new data
  ///
  /// Updates the existing route while preserving its saved date and ID.
  /// Works for both local and cloud routes.
  Future<SavedRoute> overwriteRoute({
    required SavedRoute existingRoute,
    required List<LatLng> routePoints,
    required bool loopClosed,
    String? description,
    bool? isPublic,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '$_logPrefix Overwriting route: "${existingRoute.name}" '
          '(ID: ${existingRoute.firestoreId ?? "local"})',
        );
      }

      // Create updated route preserving original metadata
      final updatedRoute = existingRoute.copyWith(
        points: routePoints
            .map((p) => LatLngData(p.latitude, p.longitude))
            .toList(),
        loopClosed: loopClosed,
        description: description,
        isPublic: isPublic ?? existingRoute.isPublic,
        // Preserve original savedAt and firestoreId
      );

      // Update in local storage
      await _localService.updateRoute(existingRoute, updatedRoute);

      // Update in cloud storage if it's a cloud route
      if (existingRoute.firestoreId != null && _userId != null) {
        try {
          final cloudUpdatedRoute = await _cloudService.saveRoute(updatedRoute);

          if (kDebugMode) {
            print(
              '$_logPrefix ✅ Route overwritten in cloud: ${cloudUpdatedRoute.firestoreId}',
            );
          }

          return cloudUpdatedRoute;
        } catch (cloudError) {
          if (kDebugMode) {
            print('$_logPrefix ⚠️ Cloud overwrite failed: $cloudError');
            print('$_logPrefix Route overwritten locally only');
          }
          // Return local updated route even if cloud update fails
          return updatedRoute;
        }
      } else {
        if (kDebugMode) {
          print('$_logPrefix Route overwritten locally only');
        }
        return updatedRoute;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to overwrite route: $e');
      }
      rethrow;
    }
  }
}
