import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

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

  SavedRoute({
    required this.name,
    required this.points,
    required this.loopClosed,
    required this.savedAt,
    this.description,
    this.distance,
  });

  /// Create SavedRoute from LatLng points
  factory SavedRoute.fromLatLng({
    required String name,
    required List<LatLng> latLngPoints,
    required bool loopClosed,
    DateTime? savedAt,
    String? description,
    double? distance,
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
