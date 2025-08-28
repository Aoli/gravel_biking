import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'saved_route.g.dart';

/// Data model for saved routes with Hive support
@HiveType(typeId: 0)
class SavedRoute extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List<LatLngData> points;

  @HiveField(2)
  final bool loopClosed;

  @HiveField(3)
  final DateTime savedAt;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final double? distance;

  @HiveField(6)
  final bool isPublic;

  @HiveField(7)
  final String? userId;

  @HiveField(8)
  final String? firestoreId;

  @HiveField(9)
  final DateTime? lastSynced;

  SavedRoute({
    required this.name,
    required this.points,
    required this.loopClosed,
    required this.savedAt,
    this.description,
    this.distance,
    this.isPublic = false,
    this.userId,
    this.firestoreId,
    this.lastSynced,
  });

  /// Create SavedRoute from LatLng points
  factory SavedRoute.fromLatLng({
    required String name,
    required List<LatLng> latLngPoints,
    required bool loopClosed,
    DateTime? savedAt,
    String? description,
    double? distance,
    bool isPublic = false,
    String? userId,
    String? firestoreId,
    DateTime? lastSynced,
  }) {
    return SavedRoute(
      name: name,
      points: latLngPoints
          .map((p) => LatLngData(p.latitude, p.longitude))
          .toList(),
      loopClosed: loopClosed,
      savedAt: savedAt ?? DateTime.now(),
      description: description,
      distance: distance,
      isPublic: isPublic,
      userId: userId,
      firestoreId: firestoreId,
      lastSynced: lastSynced,
    );
  }

  /// Get LatLng points for map operations
  List<LatLng> get latLngPoints =>
      points.map((p) => LatLng(p.latitude, p.longitude)).toList();

  /// Legacy JSON support for migration
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'points': points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'loopClosed': loopClosed,
      'savedAt': savedAt.toIso8601String(),
      'description': description,
      'distance': distance,
      'isPublic': isPublic,
      'userId': userId,
      'firestoreId': firestoreId,
      'lastSynced': lastSynced?.toIso8601String(),
    };
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'points': points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'loopClosed': loopClosed,
      'savedAt': savedAt,
      'description': description,
      'distance': distance,
      'isPublic': isPublic,
      'userId': userId,
      'lastSynced': DateTime.now(),
    };
  }

  /// Legacy JSON support for migration
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      name: json['name'],
      points: (json['points'] as List)
          .map((p) => LatLngData(p['lat'], p['lng']))
          .toList(),
      loopClosed: json['loopClosed'] ?? false,
      savedAt: DateTime.parse(json['savedAt']),
      description: json['description'],
      distance: json['distance']?.toDouble(),
      isPublic: json['isPublic'] ?? false,
      userId: json['userId'],
      firestoreId: json['firestoreId'],
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'])
          : null,
    );
  }

  /// Create from Firestore document
  factory SavedRoute.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return SavedRoute(
      name: data['name'] ?? '',
      points:
          (data['points'] as List?)
              ?.map(
                (p) => LatLngData(
                  p['lat']?.toDouble() ?? 0.0,
                  p['lng']?.toDouble() ?? 0.0,
                ),
              )
              .toList() ??
          [],
      loopClosed: data['loopClosed'] ?? false,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      distance: data['distance']?.toDouble(),
      isPublic: data['isPublic'] ?? false,
      userId: data['userId'],
      firestoreId: documentId,
      lastSynced: (data['lastSynced'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy with updated fields
  SavedRoute copyWith({
    String? name,
    List<LatLngData>? points,
    bool? loopClosed,
    DateTime? savedAt,
    String? description,
    double? distance,
    bool? isPublic,
    String? userId,
    String? firestoreId,
    DateTime? lastSynced,
  }) {
    return SavedRoute(
      name: name ?? this.name,
      points: points ?? this.points,
      loopClosed: loopClosed ?? this.loopClosed,
      savedAt: savedAt ?? this.savedAt,
      description: description ?? this.description,
      distance: distance ?? this.distance,
      isPublic: isPublic ?? this.isPublic,
      userId: userId ?? this.userId,
      firestoreId: firestoreId ?? this.firestoreId,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}

/// Hive-compatible LatLng data class
@HiveType(typeId: 1)
class LatLngData {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  LatLngData(this.latitude, this.longitude);
}
