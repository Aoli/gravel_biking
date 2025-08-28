import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Provider for measure mode state
///
/// Controls whether the map is in measurement mode (true) or view mode (false).
/// In measure mode, users can add/edit route points.
/// In view mode, only start/end points are shown with enhanced visualization.
final measureModeProvider = StateProvider<bool>((ref) => false);

/// Provider for gravel overlay visibility
///
/// Controls whether the gravel roads overlay is displayed on the map.
final gravelOverlayProvider = StateProvider<bool>((ref) => false);

/// Provider for distance markers visibility
///
/// Controls whether distance markers are shown along the route.
final distanceMarkersProvider = StateProvider<bool>((ref) => false);

/// Provider for distance marker interval
///
/// Sets the interval (in meters) between distance markers on the route.
/// Default is 1000 meters (1 km).
final distanceIntervalProvider = StateProvider<double>((ref) => 1000.0);

/// Provider for current editing index
///
/// Holds the index of the route point currently being edited.
/// Null means no point is being edited.
final editingIndexProvider = StateProvider<int?>((ref) => null);

/// Route State Management
///
/// Represents the complete state of a route including points, loop status,
/// and distance markers. This is the central state management for route editing.
class RouteState {
  final List<LatLng> routePoints;
  final bool loopClosed;
  final List<LatLng> distanceMarkers;

  const RouteState({
    required this.routePoints,
    required this.loopClosed,
    required this.distanceMarkers,
  });

  /// Creates an empty route state
  RouteState.empty()
    : routePoints = const [],
      loopClosed = false,
      distanceMarkers = const [];

  /// Creates a copy with optional parameter overrides
  RouteState copyWith({
    List<LatLng>? routePoints,
    bool? loopClosed,
    List<LatLng>? distanceMarkers,
  }) {
    return RouteState(
      routePoints: routePoints ?? List<LatLng>.from(this.routePoints),
      loopClosed: loopClosed ?? this.loopClosed,
      distanceMarkers:
          distanceMarkers ?? List<LatLng>.from(this.distanceMarkers),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteState &&
        other.routePoints.length == routePoints.length &&
        other.loopClosed == loopClosed &&
        other.distanceMarkers.length == distanceMarkers.length;
  }

  @override
  int get hashCode =>
      Object.hash(routePoints.length, loopClosed, distanceMarkers.length);
}

/// Provider for route state management
///
/// Manages the complete route state including points, loop status, and distance markers.
/// This is the central provider for all route-related state.
// Removed legacy routeStateProvider in favor of RouteNotifier-based state.

/// Provider for loop closed state (derived from RouteNotifier state)
///
/// Controls whether the current route forms a closed loop.
/// This reads from [routeNotifierProvider] so UI reflects toggle/set operations.
final loopClosedProvider = Provider<bool>((ref) {
  return ref.watch(routeNotifierProvider).loopClosed;
});

/// Provider for route points (derived from RouteNotifier state)
///
/// Provides access to the current route points list.
/// This reads from [routeNotifierProvider] so mutations are reflected.
final routePointsProvider = Provider<List<LatLng>>((ref) {
  return ref.watch(routeNotifierProvider).routePoints;
});

/// RouteNotifier for complex route operations
///
/// Handles complex route operations like adding points, toggling loop,
/// updating distance markers, etc. This centralizes all route mutations.
class RouteNotifier extends StateNotifier<RouteState> {
  RouteNotifier() : super(RouteState.empty());

  /// Add a new point to the route
  void addPoint(LatLng point) {
    final newPoints = [...state.routePoints, point];
    state = state.copyWith(
      routePoints: newPoints,
      loopClosed: false, // Auto-open when adding points
    );
  }

  /// Insert a point at a specific index
  void insertPoint(int index, LatLng point) {
    final newPoints = [...state.routePoints];
    newPoints.insert(index, point);
    state = state.copyWith(routePoints: newPoints);
  }

  /// Update a point at a specific index
  void updatePoint(int index, LatLng point) {
    if (index < 0 || index >= state.routePoints.length) return;
    final newPoints = [...state.routePoints];
    newPoints[index] = point;
    state = state.copyWith(routePoints: newPoints);
  }

  /// Remove a point at a specific index
  void removePoint(int index) {
    if (index < 0 || index >= state.routePoints.length) return;
    final newPoints = [...state.routePoints];
    newPoints.removeAt(index);
    state = state.copyWith(routePoints: newPoints);
  }

  /// Toggle the loop closed state
  void toggleLoop() {
    state = state.copyWith(loopClosed: !state.loopClosed);
  }

  /// Set the loop closed state
  void setLoopClosed(bool closed) {
    state = state.copyWith(loopClosed: closed);
  }

  /// Clear all route points
  void clearRoute() {
    state = RouteState.empty();
  }

  /// Load route from points and loop state
  void loadRoute(List<LatLng> points, bool loopClosed) {
    state = state.copyWith(routePoints: points, loopClosed: loopClosed);
  }

  /// Update distance markers
  void updateDistanceMarkers(List<LatLng> markers) {
    state = state.copyWith(distanceMarkers: markers);
  }
}

/// Provider for route operations
///
/// Provides access to RouteNotifier for performing route mutations.
/// Use this provider when you need to modify route state.
final routeNotifierProvider = StateNotifierProvider<RouteNotifier, RouteState>((
  ref,
) {
  return RouteNotifier();
});

/// Computed provider for total route distance
///
/// Calculates the total distance of the current route in meters.
/// This is a computed provider that reads from routeNotifierProvider.
final totalDistanceProvider = Provider<double>((ref) {
  final routeState = ref.watch(routeNotifierProvider);
  if (routeState.routePoints.length < 2) return 0.0;

  // Calculate total distance (simplified - real implementation would use proper distance calculation)
  double total = 0.0;
  for (int i = 1; i < routeState.routePoints.length; i++) {
    // This is a placeholder - in real implementation you'd use the Distance utility
    total += 100; // Simplified placeholder
  }

  if (routeState.loopClosed && routeState.routePoints.length >= 3) {
    total += 100; // Add closing segment distance (placeholder)
  }

  return total;
});
