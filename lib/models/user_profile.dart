import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for Firestore storage
///
/// Represents user metadata and preferences stored in the users collection.
class UserProfile {
  final String userId;
  final String? displayName;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int routeCount;
  final int publicRouteCount;
  final bool isAnonymous;

  const UserProfile({
    required this.userId,
    this.displayName,
    required this.createdAt,
    required this.lastActiveAt,
    this.routeCount = 0,
    this.publicRouteCount = 0,
    this.isAnonymous = true,
  });

  /// Create UserProfile from Firestore document
  factory UserProfile.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return UserProfile(
      userId: documentId,
      displayName: data['displayName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt:
          (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      routeCount: data['routeCount'] as int? ?? 0,
      publicRouteCount: data['publicRouteCount'] as int? ?? 0,
      isAnonymous: data['isAnonymous'] as bool? ?? true,
    );
  }

  /// Convert UserProfile to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'routeCount': routeCount,
      'publicRouteCount': publicRouteCount,
      'isAnonymous': isAnonymous,
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? userId,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? routeCount,
    int? publicRouteCount,
    bool? isAnonymous,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      routeCount: routeCount ?? this.routeCount,
      publicRouteCount: publicRouteCount ?? this.publicRouteCount,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  /// Generate display name for anonymous users
  String get effectiveDisplayName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (isAnonymous) {
      return 'Anonymous User ${userId.substring(0, 6)}';
    }
    return 'User ${userId.substring(0, 6)}';
  }

  @override
  String toString() {
    return 'UserProfile(userId: $userId, displayName: $displayName, '
        'routeCount: $routeCount, publicRouteCount: $publicRouteCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.createdAt == createdAt &&
        other.lastActiveAt == lastActiveAt &&
        other.routeCount == routeCount &&
        other.publicRouteCount == publicRouteCount &&
        other.isAnonymous == isAnonymous;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        displayName.hashCode ^
        createdAt.hashCode ^
        lastActiveAt.hashCode ^
        routeCount.hashCode ^
        publicRouteCount.hashCode ^
        isAnonymous.hashCode;
  }
}
