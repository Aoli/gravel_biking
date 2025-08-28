import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication Service
///
/// Handles anonymous authentication for the Gravel First app.
/// Anonymous users can use all app features without creating an account.
class AuthService {
  static const String _logPrefix = 'AuthService:';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user (nullable)
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Get current user ID (null if not signed in)
  String? get userId => currentUser?.uid;

  /// Sign in anonymously
  ///
  /// Creates an anonymous user account that can be used immediately.
  /// Anonymous accounts are temporary and will be lost if the app is uninstalled
  /// or user data is cleared.
  Future<UserCredential?> signInAnonymously() async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Attempting anonymous sign-in...');
      }

      final UserCredential result = await _auth.signInAnonymously();

      if (kDebugMode) {
        print('$_logPrefix ✅ Anonymous sign-in successful');
        print('$_logPrefix User ID: ${result.user?.uid}');
        print('$_logPrefix Is anonymous: ${result.user?.isAnonymous}');
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Firebase Auth Error: ${e.code}');
        print('$_logPrefix Message: ${e.message}');
      }

      // Re-throw with more context
      throw AuthException(
        'Failed to sign in anonymously: ${e.message}',
        e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Unexpected error during anonymous sign-in: $e');
      }

      throw AuthException(
        'Unexpected error during anonymous sign-in: $e',
        'unknown',
      );
    }
  }

  /// Sign out current user
  ///
  /// Signs out the current user and clears the authentication state.
  /// For anonymous users, this will permanently delete the account.
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Signing out user: ${currentUser?.uid}');
      }

      await _auth.signOut();

      if (kDebugMode) {
        print('$_logPrefix ✅ User signed out successfully');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Firebase Auth Error during sign out: ${e.code}');
        print('$_logPrefix Message: ${e.message}');
      }

      throw AuthException('Failed to sign out: ${e.message}', e.code);
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Unexpected error during sign out: $e');
      }

      throw AuthException('Unexpected error during sign out: $e', 'unknown');
    }
  }

  /// Delete current user account
  ///
  /// Permanently deletes the current user account.
  /// This is irreversible for anonymous users.
  Future<void> deleteUser() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in', 'no-user');
      }

      if (kDebugMode) {
        print('$_logPrefix Deleting user account: ${user.uid}');
      }

      await user.delete();

      if (kDebugMode) {
        print('$_logPrefix ✅ User account deleted successfully');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
          '$_logPrefix ❌ Firebase Auth Error during account deletion: ${e.code}',
        );
        print('$_logPrefix Message: ${e.message}');
      }

      throw AuthException(
        'Failed to delete user account: ${e.message}',
        e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Unexpected error during account deletion: $e');
      }

      throw AuthException(
        'Unexpected error during account deletion: $e',
        'unknown',
      );
    }
  }

  /// Auto-sign in if not already signed in
  ///
  /// Automatically signs in anonymously if no user is currently signed in.
  /// This provides a seamless experience for users.
  /// Includes network connectivity check before attempting authentication.
  Future<void> ensureSignedIn() async {
    try {
      if (!isSignedIn) {
        if (kDebugMode) {
          print(
            '$_logPrefix No user signed in, checking network connectivity...',
          );
        }

        // Test network connectivity by attempting to reach Firebase
        await _testFirebaseConnectivity();

        if (kDebugMode) {
          print('$_logPrefix Network check passed, performing auto sign-in...');
        }

        await signInAnonymously();
      } else {
        if (kDebugMode) {
          print('$_logPrefix User already signed in: $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix Auto sign-in failed: $e');
      }
      // Don't rethrow - app should continue even if auth fails
    }
  }

  /// Test Firebase connectivity
  Future<void> _testFirebaseConnectivity() async {
    try {
      // Simple connectivity test by checking if we can access Firebase Auth
      await _auth.fetchSignInMethodsForEmail('test@example.com');
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix Network connectivity check failed: $e');
      }
      throw AuthException(
        'Network connectivity required for authentication',
        'network-error',
      );
    }
  }

  /// Initialize authentication with automatic sign-in
  ///
  /// Call this during app startup to automatically authenticate users.
  /// This ensures users are authenticated before using Firestore features.
  Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('$_logPrefix Initializing authentication...');
      }

      // Wait for auth state to be determined
      final user = _auth.currentUser;
      if (user != null) {
        if (kDebugMode) {
          print('$_logPrefix User already authenticated: ${user.uid}');
        }
        return;
      }

      // Auto sign-in if no user is present
      await ensureSignedIn();

      if (kDebugMode) {
        print('$_logPrefix ✅ Authentication initialization complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$_logPrefix ❌ Authentication initialization failed: $e');
      }
      // Don't rethrow - app should continue with limited functionality
    }
  }

  /// Get user display information
  ///
  /// Returns basic information about the current user.
  /// For anonymous users, this includes limited information.
  Map<String, dynamic> getUserInfo() {
    final user = currentUser;
    if (user == null) {
      return {'signedIn': false};
    }

    return {
      'signedIn': true,
      'userId': user.uid,
      'isAnonymous': user.isAnonymous,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      'providerData': user.providerData
          .map((p) => {'providerId': p.providerId, 'uid': p.uid})
          .toList(),
    };
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  const AuthException(this.message, this.code);

  final String message;
  final String code;

  @override
  String toString() => 'AuthException($code): $message';
}
