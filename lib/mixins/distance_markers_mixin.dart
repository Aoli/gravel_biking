import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/ui_providers.dart';

/// Mixin that encapsulates distance marker generation logic.
///
/// Requirements for the host State class:
/// - Provide [routePoints], [distanceMarkers], and a [distance] calculator.
/// - Expose [ref] (from ConsumerState) and [saveStateForUndo] to snapshot state.
/// - Implement [requestRebuild] to trigger a UI update after markers change.
mixin DistanceMarkersMixin {
  // Host-provided members
  List<LatLng> get routePoints;
  List<LatLng> get distanceMarkers;
  Distance get distance;
  WidgetRef get ref;

  void saveStateForUndo();
  void requestRebuild();

  /// Generate distance markers along the current route.
  /// Uses the distance interval from [distanceIntervalProvider].
  void recalcDistanceMarkers() {
    if (routePoints.length < 2) return;

    saveStateForUndo();
    distanceMarkers.clear();
    final intervalMeters = ref.read(distanceIntervalProvider); // in meters

    double currentDistance = 0.0;
    double nextMarkerDistance = intervalMeters;

    for (int i = 1; i < routePoints.length; i++) {
      final segmentDistance = distance.as(
        LengthUnit.Meter,
        routePoints[i - 1],
        routePoints[i],
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + segmentDistance;

      // Place marker(s) within this segment
      while (nextMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / segmentDistance;

        final lat =
            routePoints[i - 1].latitude +
            ((routePoints[i].latitude - routePoints[i - 1].latitude) * ratio);
        final lon =
            routePoints[i - 1].longitude +
            ((routePoints[i].longitude - routePoints[i - 1].longitude) * ratio);

        distanceMarkers.add(LatLng(lat, lon));
        nextMarkerDistance += intervalMeters;
      }

      currentDistance = segmentEnd;
    }

    // Handle closed loop - check closing segment
    if (ref.read(loopClosedProvider) && routePoints.length >= 3) {
      final closingDistance = distance.as(
        LengthUnit.Meter,
        routePoints.last,
        routePoints.first,
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + closingDistance;

      while (nextMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / closingDistance;

        final lat =
            routePoints.last.latitude +
            ((routePoints.first.latitude - routePoints.last.latitude) * ratio);
        final lon =
            routePoints.last.longitude +
            ((routePoints.first.longitude - routePoints.last.longitude) *
                ratio);

        distanceMarkers.add(LatLng(lat, lon));
        nextMarkerDistance += intervalMeters;
      }
    }

    // Respect user's display preference; just trigger a rebuild
    requestRebuild();
  }

  /// Auto-generate distance markers whenever route changes.
  void autoRecalcDistanceMarkers() {
    if (routePoints.length >= 2) {
      recalcDistanceMarkers();
    }
  }
}
