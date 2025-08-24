import 'dart:convert';

/// Utility functions for coordinate and data processing
class CoordinateUtils {
  /// Extract polyline coordinates from Overpass API response
  static List<List<List<double>>> extractPolylineCoords(String body) {
    final data = json.decode(body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? const [];
    final result = <List<List<double>>>[];

    for (final e in elements) {
      if (e is Map && e['type'] == 'way' && e['geometry'] is List) {
        final pts = <List<double>>[];
        for (final n in (e['geometry'] as List)) {
          if (n is Map && n['lat'] is num && n['lon'] is num) {
            pts.add([
              (n['lat'] as num).toDouble(),
              (n['lon'] as num).toDouble(),
            ]);
          }
        }
        if (pts.length >= 2) result.add(pts);
      }
    }

    return result;
  }

  /// Format distance in meters to human readable string
  static String formatDistance(double meters) {
    if (meters < 950) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }
}
