/// Route State Model for Undo Functionality
///
/// Represents a snapshot of the route state that can be stored and restored
/// for implementing comprehensive undo/redo functionality in route editing.
library;

import 'package:latlong2/latlong.dart';

/// Represents a snapshot of the route state for undo functionality
///
/// This class captures the complete state of a route at a specific point in time,
/// allowing the application to implement comprehensive undo/redo functionality
/// for all route editing operations.
///
/// **State Captured:**
/// - Route points (complete coordinate list)
/// - Loop closure status
/// - Distance markers visibility state
/// - Distance markers positions
///
/// **Usage:**
/// Used by the route editing system to save state before any destructive
/// operation (add point, delete point, toggle loop, etc.) and restore
/// previous states when user triggers undo operations.
class RouteStateSnapshot {
  final List<LatLng> routePoints;
  final bool loopClosed;
  final bool showDistanceMarkers;
  final List<LatLng> distanceMarkers;

  const RouteStateSnapshot({
    required this.routePoints,
    required this.loopClosed,
    required this.showDistanceMarkers,
    required this.distanceMarkers,
  });

  /// Create a snapshot from current state values
  ///
  /// Creates deep copies of mutable collections to ensure the snapshot
  /// remains immutable and independent of the original state.
  RouteStateSnapshot.fromCurrent({
    required List<LatLng> routePoints,
    required bool loopClosed,
    required bool showDistanceMarkers,
    required List<LatLng> distanceMarkers,
  }) : this(
         routePoints: List<LatLng>.from(routePoints),
         loopClosed: loopClosed,
         showDistanceMarkers: showDistanceMarkers,
         distanceMarkers: List<LatLng>.from(distanceMarkers),
       );

  /// Create a copy with modified values
  RouteStateSnapshot copyWith({
    List<LatLng>? routePoints,
    bool? loopClosed,
    bool? showDistanceMarkers,
    List<LatLng>? distanceMarkers,
  }) {
    return RouteStateSnapshot(
      routePoints: routePoints ?? List<LatLng>.from(this.routePoints),
      loopClosed: loopClosed ?? this.loopClosed,
      showDistanceMarkers: showDistanceMarkers ?? this.showDistanceMarkers,
      distanceMarkers:
          distanceMarkers ?? List<LatLng>.from(this.distanceMarkers),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RouteStateSnapshot) return false;

    return loopClosed == other.loopClosed &&
        showDistanceMarkers == other.showDistanceMarkers &&
        routePoints.length == other.routePoints.length &&
        distanceMarkers.length == other.distanceMarkers.length;
  }

  @override
  int get hashCode => Object.hash(
    routePoints.length,
    loopClosed,
    showDistanceMarkers,
    distanceMarkers.length,
  );

  @override
  String toString() {
    return 'RouteStateSnapshot('
        'routePoints: ${routePoints.length}, '
        'loopClosed: $loopClosed, '
        'showDistanceMarkers: $showDistanceMarkers, '
        'distanceMarkers: ${distanceMarkers.length}'
        ')';
  }
}
