import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for accessing Trafikverket's NVDB (Nationella Vägdatabasen) API
///
/// NVDB contains official Swedish road network data including surface types
/// that are perfect for identifying gravel roads and unpaved surfaces.
///
/// API Documentation: https://nvdb2012.trafikverket.se/
/// No API key required for basic queries
class NvdbService {
  static const String _baseUrl = 'https://nvdb2012.trafikverket.se';
  static const Duration _timeout = Duration(seconds: 30);

  // Object types we're interested in for gravel biking
  // static const Map<int, String> _surfaceObjectTypes = {
  //   // Vägyta (Road surface) - objekttyp 97
  //   97: 'road_surface',
  //   // Vägnät (Road network) - objekttyp 17
  //   17: 'road_network',
  // };

  final http.Client _client;

  NvdbService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for gravel and unpaved roads within a bounding box
  ///
  /// [bbox] Geographic bounding box (south, west, north, east)
  /// Returns list of road segments with gravel/unpaved surfaces
  Future<List<NvdbRoadSegment>> getGravelRoads(LatLngBounds bbox) async {
    try {
      // Query for road surface data (objekttyp 97)
      final surfaceData = await _queryRoadSurfaces(bbox);

      // Filter for gravel and unpaved surfaces
      final gravelSegments = _filterGravelSurfaces(surfaceData);

      debugPrint('NVDB: Found ${gravelSegments.length} gravel road segments');
      return gravelSegments;
    } catch (e, stackTrace) {
      debugPrint('NVDB Service Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Query NVDB for road surface data within bounding box
  Future<Map<String, dynamic>> _queryRoadSurfaces(LatLngBounds bbox) async {
    // NVDB uses SWEREF99 TM coordinate system, but also accepts WGS84
    final query = {
      'bbox': '${bbox.west},${bbox.south},${bbox.east},${bbox.north}',
      'srid': '4326', // WGS84
      'format': 'json',
      'inkludera': 'egenskaper,geometri',
    };

    final uri = Uri.parse(
      '$_baseUrl/api/v2/objekt/97',
    ).replace(queryParameters: query);

    debugPrint('NVDB Query: $uri');

    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw NvdbException(
        'NVDB API error: ${response.statusCode}',
        response.body,
      );
    }
  }

  /// Filter road segments to include only gravel and unpaved surfaces
  List<NvdbRoadSegment> _filterGravelSurfaces(Map<String, dynamic> data) {
    final segments = <NvdbRoadSegment>[];

    final objects = data['objekt'] as List<dynamic>? ?? [];

    for (final obj in objects) {
      try {
        final segment = _parseRoadObject(obj as Map<String, dynamic>);
        if (segment != null && _isGravelSurface(segment.surfaceType)) {
          segments.add(segment);
        }
      } catch (e) {
        debugPrint('Error parsing NVDB object: $e');
        // Continue processing other objects
      }
    }

    return segments;
  }

  /// Parse a single NVDB road object
  NvdbRoadSegment? _parseRoadObject(Map<String, dynamic> obj) {
    try {
      // Extract geometry
      final lokation = obj['lokation'] as Map<String, dynamic>?;
      final geometri = lokation?['geometrilinje'] as Map<String, dynamic>?;
      final coordinates = geometri?['coordinates'] as List<dynamic>?;

      if (coordinates == null || coordinates.isEmpty) {
        return null;
      }

      // Parse coordinates to LatLng points
      final points = <LatLng>[];
      for (final coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          final lon = (coord[0] as num).toDouble();
          final lat = (coord[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }

      if (points.isEmpty) return null;

      // Extract surface type from properties
      final egenskaper = obj['egenskaper'] as List<dynamic>? ?? [];
      String surfaceType = 'unknown';

      for (final prop in egenskaper) {
        if (prop is Map<String, dynamic>) {
          final typeId = prop['typeId'] as int?;
          final value = prop['varde'] as String?;

          // Surface type property (varies by object type)
          if (typeId == 4002 && value != null) {
            // Vagytans material
            surfaceType = value.toLowerCase();
            break;
          }
        }
      }

      return NvdbRoadSegment(
        id: obj['id'] as int? ?? 0,
        points: points,
        surfaceType: surfaceType,
        roadClass: _extractRoadClass(obj),
      );
    } catch (e) {
      debugPrint('Error parsing NVDB road object: $e');
      return null;
    }
  }

  /// Check if surface type indicates gravel or unpaved road
  bool _isGravelSurface(String surfaceType) {
    final gravelSurfaces = {
      'grus',
      'makadam',
      'sten',
      'naturmaterial',
      'jord',
      'sand',
      'singel',
      'kross',
      'obefintlig',
      'naturlig',
    };

    return gravelSurfaces.any(
      (surface) => surfaceType.toLowerCase().contains(surface),
    );
  }

  /// Extract road classification from NVDB object
  String _extractRoadClass(Map<String, dynamic> obj) {
    final egenskaper = obj['egenskaper'] as List<dynamic>? ?? [];

    for (final prop in egenskaper) {
      if (prop is Map<String, dynamic>) {
        final typeId = prop['typeId'] as int?;
        final value = prop['varde'] as String?;

        // Road class property
        if (typeId == 1002 && value != null) {
          // Vaghallare
          return value;
        }
      }
    }

    return 'unknown';
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

/// Represents a road segment from NVDB with gravel surface
class NvdbRoadSegment {
  final int id;
  final List<LatLng> points;
  final String surfaceType;
  final String roadClass;

  const NvdbRoadSegment({
    required this.id,
    required this.points,
    required this.surfaceType,
    required this.roadClass,
  });

  @override
  String toString() {
    return 'NvdbRoadSegment(id: $id, points: ${points.length}, '
        'surface: $surfaceType, class: $roadClass)';
  }
}

/// Exception thrown by NVDB service
class NvdbException implements Exception {
  final String message;
  final String? response;

  const NvdbException(this.message, [this.response]);

  @override
  String toString() {
    return 'NvdbException: $message${response != null ? '\nResponse: $response' : ''}';
  }
}

/// Geographic bounding box for NVDB queries
class LatLngBounds {
  final double south;
  final double west;
  final double north;
  final double east;

  const LatLngBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Create bounds from center point and radius (in degrees)
  factory LatLngBounds.fromCenter(LatLng center, double radiusDegrees) {
    return LatLngBounds(
      south: center.latitude - radiusDegrees,
      west: center.longitude - radiusDegrees,
      north: center.latitude + radiusDegrees,
      east: center.longitude + radiusDegrees,
    );
  }

  @override
  String toString() {
    return 'LatLngBounds(south: $south, west: $west, north: $north, east: $east)';
  }
}
