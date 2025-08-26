import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Service for route measurement and distance calculations
class MeasurementService {
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  final List<LatLng> _distanceMarkers = [];

  bool _measureEnabled = false;
  bool _loopClosed = false;
  bool _editModeEnabled = false;
  int? _editingIndex;
  bool _showDistanceMarkers = true;
  double _distanceInterval = 1.0; // Default 1km intervals

  // Getters
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  List<double> get segmentMeters => List.unmodifiable(_segmentMeters);
  List<LatLng> get distanceMarkers => List.unmodifiable(_distanceMarkers);
  bool get measureEnabled => _measureEnabled;
  bool get loopClosed => _loopClosed;
  bool get editModeEnabled => _editModeEnabled;
  int? get editingIndex => _editingIndex;
  bool get showDistanceMarkers => _showDistanceMarkers;
  double get distanceInterval => _distanceInterval;

  // Setters
  set measureEnabled(bool value) => _measureEnabled = value;
  set editModeEnabled(bool value) {
    _editModeEnabled = value;
    if (!value) _editingIndex = null;
  }

  set editingIndex(int? value) => _editingIndex = value;
  set showDistanceMarkers(bool value) => _showDistanceMarkers = value;
  set distanceInterval(double value) => _distanceInterval = value;

  /// Add a route point
  void addRoutePoint(LatLng point) {
    if (_loopClosed) _loopClosed = false; // re-open when adding
    _routePoints.add(point);
    _recomputeSegments();
    _updateDistanceMarkersIfVisible();
  }

  /// Move a route point to a new position
  void moveRoutePoint(int index, LatLng newPosition) {
    if (index >= 0 && index < _routePoints.length) {
      _routePoints[index] = newPosition;
      _editingIndex = null;
      _recomputeSegments();
      _updateDistanceMarkersIfVisible();
    }
  }

  /// Remove the last route point
  void undoLastPoint() {
    if (_routePoints.isEmpty) return;
    _routePoints.removeLast();
    if (_routePoints.length < 3) _loopClosed = false;
    _recomputeSegments();
  }

  /// Clear all route points
  void clearRoute() {
    _routePoints.clear();
    _distanceMarkers.clear();
    _segmentMeters.clear();
    _loopClosed = false;
    _editingIndex = null;
    _showDistanceMarkers = false;
  }

  /// Add a point between two existing points
  void addPointBetween(int beforeIndex, int afterIndex, LatLng midpoint) {
    if (afterIndex == 0 && beforeIndex == _routePoints.length - 1) {
      // Adding between last and first point (loop closure)
      _routePoints.add(midpoint);
      _editingIndex = _routePoints.length - 1;
    } else {
      // Adding between consecutive points
      _routePoints.insert(afterIndex, midpoint);
      _editingIndex = afterIndex;
    }
    _recomputeSegments();
    _updateDistanceMarkersIfVisible();
  }

  /// Delete a route point
  void deletePoint(int index) {
    if (index < 0 || index >= _routePoints.length) return;
    _routePoints.removeAt(index);
    _distanceMarkers.clear();
    if (_routePoints.length < 3) _loopClosed = false;
    if (_editingIndex != null) {
      if (_routePoints.isEmpty) {
        _editingIndex = null;
      } else if (index == _editingIndex) {
        _editingIndex = null;
      } else if (index < _editingIndex!) {
        _editingIndex = _editingIndex! - 1;
      }
    }
    _recomputeSegments();
    _updateDistanceMarkersIfVisible();
  }

  /// Toggle loop closure
  void toggleLoop() {
    if (_routePoints.length < 3) return;
    _loopClosed = !_loopClosed;
    _recomputeSegments();
    _updateDistanceMarkersIfVisible();
  }

  /// Load route points from external source
  void loadRoute(List<LatLng> points, {bool loopClosed = false}) {
    _routePoints.clear();
    _distanceMarkers.clear();
    _routePoints.addAll(points);
    _segmentMeters.clear();
    _editingIndex = null;
    _loopClosed = loopClosed && points.length >= 3;
    _recomputeSegments();
  }

  /// Calculate dynamic point size based on route density
  double calculateDynamicPointSize() {
    if (_routePoints.length < 2) return 18.0;

    double totalDistance = 0.0;
    int validSegments = 0;

    for (int i = 1; i < _routePoints.length; i++) {
      final segmentDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
      if (segmentDistance > 0) {
        totalDistance += segmentDistance;
        validSegments++;
      }
    }

    if (validSegments == 0) return 18.0;
    final averageDistance = totalDistance / validSegments;

    if (averageDistance > 1000) return 20.0;
    if (averageDistance > 500) return 18.0;
    if (averageDistance > 200) return 16.0;
    if (averageDistance > 100) return 14.0;
    if (averageDistance > 50) return 12.0;
    return 10.0;
  }

  /// Generate distance markers along the route
  void generateDistanceMarkers() {
    if (_routePoints.length < 2) return;

    _distanceMarkers.clear();
    final intervalMeters = _distanceInterval * 1000;

    double currentDistance = 0.0;
    double nextMarkerDistance = intervalMeters;

    for (int i = 1; i < _routePoints.length; i++) {
      final segmentDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + segmentDistance;

      while (nextMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / segmentDistance;

        final lat =
            _routePoints[i - 1].latitude +
            ((_routePoints[i].latitude - _routePoints[i - 1].latitude) * ratio);
        final lon =
            _routePoints[i - 1].longitude +
            ((_routePoints[i].longitude - _routePoints[i - 1].longitude) *
                ratio);

        _distanceMarkers.add(LatLng(lat, lon));
        nextMarkerDistance += intervalMeters;
      }

      currentDistance = segmentEnd;
    }

    // Handle closed loop
    if (_loopClosed && _routePoints.length >= 3) {
      final closingDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints.last,
        _routePoints.first,
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + closingDistance;

      while (nextMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / closingDistance;

        final lat =
            _routePoints.last.latitude +
            ((_routePoints.first.latitude - _routePoints.last.latitude) *
                ratio);
        final lon =
            _routePoints.last.longitude +
            ((_routePoints.first.longitude - _routePoints.last.longitude) *
                ratio);

        _distanceMarkers.add(LatLng(lat, lon));
        nextMarkerDistance += intervalMeters;
      }
    }

    _showDistanceMarkers = true;
  }

  /// Calculate distance from start to a specific point
  double calculateDistanceToPoint(int index) {
    if (index < 0 || index >= _routePoints.length) return 0.0;

    double distanceFromStart = 0.0;
    for (int i = 0; i < index; i++) {
      distanceFromStart += _distance.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
    }
    return distanceFromStart;
  }

  /// Center map on the route
  void centerMapOnRoute(MapController mapController) {
    if (_routePoints.isEmpty) return;

    if (_routePoints.length == 1) {
      mapController.move(_routePoints.first, 15);
    } else {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;

      for (final point in _routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      mapController.fitCamera(CameraFit.bounds(bounds: bounds));
    }
  }

  /// Recompute segment distances
  void _recomputeSegments() {
    _segmentMeters.clear();
    _segmentMeters.addAll(_computeSegments(_routePoints, _loopClosed));
  }

  /// Compute segments for the given points and loop state
  List<double> _computeSegments(List<LatLng> pts, bool closed) {
    if (pts.length < 2) return const [];
    final segs = <double>[];
    for (int i = 1; i < pts.length; i++) {
      segs.add(_distance.as(LengthUnit.Meter, pts[i - 1], pts[i]));
    }
    if (closed && pts.length >= 3) {
      segs.add(_distance.as(LengthUnit.Meter, pts.last, pts.first));
    }
    return segs;
  }

  /// Update distance markers if they are currently visible
  void _updateDistanceMarkersIfVisible() {
    if (_showDistanceMarkers && _routePoints.length >= 2) {
      generateDistanceMarkers();
    }
  }

  /// Async version for large routes to prevent UI freezing
  Future<void> recomputeSegmentsAsync() async {
    final segments = <double>[];
    final points = _routePoints;
    final closed = _loopClosed;

    if (points.length < 2) return;

    const chunkSize = 200;
    for (int start = 1; start < points.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, points.length);

      for (int i = start; i < end; i++) {
        segments.add(_distance.as(LengthUnit.Meter, points[i - 1], points[i]));
      }

      if (start % (chunkSize * 5) == 1) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    if (closed && points.length >= 3) {
      segments.add(_distance.as(LengthUnit.Meter, points.last, points.first));
    }

    _segmentMeters.clear();
    _segmentMeters.addAll(segments);
  }
}
