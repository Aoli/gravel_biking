import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Firestore service for user profile management
///
/// Handles creation, updating, and retrieval of user profiles from the users collection.
class FirestoreUserService {
  static const String _logPrefix = 'FirestoreUserService:';
  static const String _collectionName = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to users collection
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(_collectionName);

  /// Create or update user profile
  ///
  /// Creates a new user document if it doesn't exist, updates lastActiveAt if it does.
  Future<UserProfile> createOrUpdateUser(
    String userId, {
    String? displayName,
    bool isAnonymous = true,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Creating/updating user profile: $userId');
      }

      final userDoc = _usersCollection.doc(userId);
      final docSnapshot = await userDoc.get();

      if (docSnapshot.exists) {
        // Update existing user's last active time
        await userDoc.update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          if (displayName != null) 'displayName': displayName,
        });

        if (kDebugMode) {
          print('$_logPrefix ✅ User profile updated: $userId');
        }

        // Get updated profile
        final updatedDoc = await userDoc.get();
        return UserProfile.fromFirestore(updatedDoc.data()!, userId);
      } else {
        // Create new user profile
        final profile = UserProfile(
          userId: userId,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isAnonymous: isAnonymous,
        );

        await userDoc.set(profile.toFirestore());

        if (kDebugMode) {
          print('$_logPrefix ✅ User profile created: $userId');
        }

        return profile;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to create/update user: $e');
      }
      rethrow;
    }
  }

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading user profile: $userId');
      }

      final docSnapshot = await _usersCollection.doc(userId).get();

      if (!docSnapshot.exists) {
        if (kDebugMode) {
          print('$_logPrefix User profile not found: $userId');
        }
        return null;
      }

      final profile = UserProfile.fromFirestore(docSnapshot.data()!, userId);

      if (kDebugMode) {
        print(
          '$_logPrefix ✅ User profile loaded: ${profile.effectiveDisplayName}',
        );
      }

      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load user profile: $e');
      }
      return null;
    }
  }

  /// Update user route counts
  ///
  /// Called when user creates, deletes, or changes visibility of routes.
  Future<void> updateRouteStats(
    String userId,
    int totalRoutes,
    int publicRoutes,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '$_logPrefix Updating route stats for $userId: $totalRoutes total, $publicRoutes public',
        );
      }

      await _usersCollection.doc(userId).update({
        'routeCount': totalRoutes,
        'publicRouteCount': publicRoutes,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('$_logPrefix ✅ Route stats updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to update route stats: $e');
      }
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Update user display name
  Future<UserProfile?> updateDisplayName(
    String userId,
    String displayName,
  ) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Updating display name for $userId: "$displayName"');
      }

      await _usersCollection.doc(userId).update({
        'displayName': displayName,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('$_logPrefix ✅ Display name updated');
      }

      // Return updated profile
      return await getUserProfile(userId);
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to update display name: $e');
      }
      rethrow;
    }
  }

  /// Get public route creators (users with public routes)
  Future<List<UserProfile>> getPublicRouteCreators({int limit = 50}) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Loading public route creators (limit: $limit)');
      }

      final querySnapshot = await _usersCollection
          .where('publicRouteCount', isGreaterThan: 0)
          .orderBy('publicRouteCount', descending: true)
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc.data(), doc.id))
          .toList();

      if (kDebugMode) {
        print('$_logPrefix ✅ Loaded ${users.length} public route creators');
      }

      return users;
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to load public route creators: $e');
      }
      return [];
    }
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String userId) async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Deleting user profile: $userId');
      }

      await _usersCollection.doc(userId).delete();

      if (kDebugMode) {
        print('$_logPrefix ✅ User profile deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Failed to delete user profile: $e');
      }
      rethrow;
    }
  }

  /// Stream user profile changes
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _usersCollection.doc(userId).snapshots().map((docSnapshot) {
      if (!docSnapshot.exists) return null;
      return UserProfile.fromFirestore(docSnapshot.data()!, userId);
    });
  }
}
