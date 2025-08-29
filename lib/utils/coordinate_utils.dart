import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Utility functions for coordinate and data processing
class CoordinateUtils {
  static const Distance _distance = Distance();

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

  /// Calculate distance between two LatLng points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    return _distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Format distance in meters to human readable string
  static String formatDistance(double meters) {
    if (meters < 950) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }
}
