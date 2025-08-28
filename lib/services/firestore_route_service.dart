import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_route.dart';

/// Firestore service for syncing routes to the cloud
///
/// Handles saving and retrieving routes from Firestore with public/private visibility.
/// Public routes are visible to all users, private routes only to the owner.
class FirestoreRouteService {
  static const String _logPrefix = 'FirestoreRouteService:';
  static const String _collectionName = 'routes';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to routes collection
  CollectionReference<Map<String, dynamic>> get _routesCollection =>
      _firestore.collection(_collectionName);

  /// Save route to Firestore
  ///
  /// Creates a new document if firestoreId is null, updates existing otherwise.
  /// Returns the updated SavedRoute with Firestore ID and sync timestamp.
  Future<SavedRoute> saveRoute(SavedRoute route) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Saving route "${route.name}" to Firestore...');
        print('$_logPrefix Public: ${route.isPublic}, User: ${route.userId}');
      }

      final data = route.toFirestore();
      DocumentReference docRef;

      if (route.firestoreId != null) {
        // Update existing document
        docRef = _routesCollection.doc(route.firestoreId!);
        await docRef.update(data);

        if (kDebugMode) {
          print(
            '$_logPrefix ✅ Route updated in Firestore: ${route.firestoreId}',
          );
        }
      } else {
        // Create new document
        docRef = await _routesCollection.add(data);

        if (kDebugMode) {
          print('$_logPrefix ✅ Route created in Firestore: ${docRef.id}');
        }
      }

      // Return updated route with Firestore metadata
      return route.copyWith(firestoreId: docRef.id, lastSynced: DateTime.now());
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to save route to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Get user's private routes from Firestore
  Future<List<SavedRoute>> getUserRoutes(String userId) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading private routes for user: $userId');
      }

      final querySnapshot = await _routesCollection
          .where('userId', isEqualTo: userId)
          .where('isPublic', isEqualTo: false)
          .orderBy('savedAt', descending: true)
          .get();

      final routes = querySnapshot.docs
          .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
          .toList();

      if (kDebugMode) {
        print('$_logPrefix ✅ Loaded ${routes.length} private routes');
      }

      return routes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load user routes: $e');
      }
      return [];
    }
  }

  /// Get public routes from Firestore
  Future<List<SavedRoute>> getPublicRoutes({int limit = 50}) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading public routes (limit: $limit)...');
      }

      final querySnapshot = await _routesCollection
          .where('isPublic', isEqualTo: true)
          .orderBy('savedAt', descending: true)
          .limit(limit)
          .get();

      final routes = querySnapshot.docs
          .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
          .toList();

      if (kDebugMode) {
        print('$_logPrefix ✅ Loaded ${routes.length} public routes');
      }

      return routes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load public routes: $e');
      }
      return [];
    }
  }

  /// Get all routes accessible to user (user's private + all public)
  Future<List<SavedRoute>> getAllAccessibleRoutes(String userId) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading all accessible routes for user: $userId');
      }

      // Get user's routes (both public and private)
      final userRoutesQuery = await _routesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('savedAt', descending: true)
          .get();

      // Get other users' public routes
      final publicRoutesQuery = await _routesCollection
          .where('isPublic', isEqualTo: true)
          .where('userId', isNotEqualTo: userId)
          .orderBy('savedAt', descending: true)
          .get();

      final userRoutes = userRoutesQuery.docs
          .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
          .toList();

      final publicRoutes = publicRoutesQuery.docs
          .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
          .toList();

      final allRoutes = [...userRoutes, ...publicRoutes];

      // Sort by save date (newest first)
      allRoutes.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      if (kDebugMode) {
        print(
          '$_logPrefix ✅ Loaded ${userRoutes.length} user routes + ${publicRoutes.length} public routes',
        );
      }

      return allRoutes;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load accessible routes: $e');
      }
      return [];
    }
  }

  /// Delete route from Firestore
  Future<void> deleteRoute(String firestoreId) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Deleting route from Firestore: $firestoreId');
      }

      await _routesCollection.doc(firestoreId).delete();

      if (kDebugMode) {
        print('$_logPrefix ✅ Route deleted from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to delete route from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Search public routes by name or description
  Future<List<SavedRoute>> searchPublicRoutes(String query) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Searching public routes for: "$query"');
      }

      // Firestore doesn't support full-text search, so we'll get all public routes
      // and filter client-side. For large datasets, consider using Algolia or similar.
      final querySnapshot = await _routesCollection
          .where('isPublic', isEqualTo: true)
          .orderBy('savedAt', descending: true)
          .get();

      final routes = querySnapshot.docs
          .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
          .toList();

      if (query.isEmpty) {
        return routes;
      }

      // Client-side filtering
      final searchLower = query.toLowerCase();
      final filtered = routes.where((route) {
        return route.name.toLowerCase().contains(searchLower) ||
            (route.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      if (kDebugMode) {
        print('$_logPrefix ✅ Found ${filtered.length} matching routes');
      }

      return filtered;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to search public routes: $e');
      }
      return [];
    }
  }

  /// Update route visibility (public/private)
  Future<void> updateRouteVisibility(String firestoreId, bool isPublic) async {
    try {
      if (kDebugMode) {
        print(
          '$_logPrefix Updating route visibility: $firestoreId -> ${isPublic ? "public" : "private"}',
        );
      }

      await _routesCollection.doc(firestoreId).update({
        'isPublic': isPublic,
        'lastSynced': FieldValue.serverTimestamp(),
      });

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

  /// Stream user's routes in real-time
  Stream<List<SavedRoute>> streamUserRoutes(String userId) {
    return _routesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs
              .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }

  /// Stream public routes in real-time
  Stream<List<SavedRoute>> streamPublicRoutes({int limit = 50}) {
    return _routesCollection
        .where('isPublic', isEqualTo: true)
        .orderBy('savedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs
              .map((doc) => SavedRoute.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }
}
