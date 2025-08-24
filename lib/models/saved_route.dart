import 'package:latlong2/latlong.dart';

/// Data model for saved routes
class SavedRoute {
  final String name;
  final List<LatLng> points;
  final bool loopClosed;
  final DateTime savedAt;

  SavedRoute({
    required this.name,
    required this.points,
    required this.loopClosed,
    required this.savedAt,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'points': points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'loopClosed': loopClosed,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      name: json['name'],
      points: (json['points'] as List)
          .map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
      loopClosed: json['loopClosed'] ?? false,
      savedAt: DateTime.parse(json['savedAt']),
    );
  }
}
