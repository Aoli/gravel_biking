import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/services/measurement_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Distance Markers Issue Tests', () {
    late MeasurementService service;

    setUp(() {
      service = MeasurementService();
    });

    test('should generate markers for closing segment when toggling loop', () {
      print('=== Testing loop closing distance marker issue ===');

      // Create a route where the closing segment would need markers
      service.addRoutePoint(const LatLng(59.0, 18.0)); // Point A
      service.addRoutePoint(const LatLng(59.1, 18.0)); // Point B (11km north)
      service.addRoutePoint(const LatLng(59.05, 18.1)); // Point C (offset east)

      // Set 5km interval for more visible results
      service.distanceInterval = 5.0;

      print('Route points added: ${service.routePoints.length}');
      print('Initial loop state: ${service.loopClosed}');

      // Calculate distances before loop closure
      final distance = Distance();
      final segmentAB = distance.as(
        LengthUnit.Meter,
        service.routePoints[0],
        service.routePoints[1],
      );
      final segmentBC = distance.as(
        LengthUnit.Meter,
        service.routePoints[1],
        service.routePoints[2],
      );
      final segmentCA = distance.as(
        LengthUnit.Meter,
        service.routePoints[2],
        service.routePoints[0],
      );

      print('Segment A-B: ${segmentAB.toStringAsFixed(0)}m');
      print('Segment B-C: ${segmentBC.toStringAsFixed(0)}m');
      print('Segment C-A (closing): ${segmentCA.toStringAsFixed(0)}m');

      final totalDistance = segmentAB + segmentBC + segmentCA;
      print('Total distance when closed: ${totalDistance.toStringAsFixed(0)}m');

      // Test 1: Generate markers BEFORE closing loop (open route)
      print('\n--- Before closing loop ---');
      service.generateDistanceMarkers();
      final markersBeforeLoop = List.from(service.distanceMarkers);
      print('Markers in open route: ${markersBeforeLoop.length}');

      // Test 2: Toggle loop (close route) - this should regenerate markers
      print('\n--- After closing loop ---');
      service.toggleLoop();
      print('Loop closed: ${service.loopClosed}');
      print('Markers after toggle: ${service.distanceMarkers.length}');

      // The issue: markers may not include the closing segment
      final markersAfterLoop = service.distanceMarkers;

      // Verify we have more markers with the closed loop
      if (totalDistance > service.distanceInterval * 1000) {
        expect(
          markersAfterLoop.length,
          greaterThan(0),
          reason: 'Should have distance markers when total distance > interval',
        );

        // Important: Closed loop should have same or more markers than open route
        // because the closing segment adds distance
        expect(
          markersAfterLoop.length,
          greaterThanOrEqualTo(markersBeforeLoop.length),
          reason:
              'Closed loop should have at least as many markers as open route',
        );
      }

      print(
        '\nTest result: ${markersAfterLoop.length >= markersBeforeLoop.length ? "PASS" : "FAIL"}',
      );
      print('Expected: Closed loop markers >= Open route markers');
      print(
        'Actual: ${markersAfterLoop.length} >= ${markersBeforeLoop.length}',
      );
    });

    test('should regenerate markers when moving waypoints', () {
      print('\n=== Testing waypoint moving distance marker regeneration ===');

      // Create a route
      service.addRoutePoint(const LatLng(59.0, 18.0)); // Point A
      service.addRoutePoint(const LatLng(59.1, 18.0)); // Point B
      service.addRoutePoint(const LatLng(59.2, 18.0)); // Point C

      // Set 5km interval
      service.distanceInterval = 5.0;

      // Generate initial markers
      service.generateDistanceMarkers();
      final initialMarkers = List.from(service.distanceMarkers);
      print('Initial markers: ${initialMarkers.length}');

      // Print initial marker positions for reference
      for (int i = 0; i < initialMarkers.length; i++) {
        print(
          'Initial marker ${i + 1}: ${initialMarkers[i].latitude.toStringAsFixed(6)}, ${initialMarkers[i].longitude.toStringAsFixed(6)}',
        );
      }

      // Move the middle point significantly (eastward)
      const newPosition = LatLng(59.1, 18.2);
      print(
        '\nMoving point 1 (middle) from ${service.routePoints[1]} to $newPosition',
      );
      service.moveRoutePoint(1, newPosition);

      final markersAfterMove = service.distanceMarkers;
      print('Markers after moving waypoint: ${markersAfterMove.length}');

      // Print new marker positions
      for (int i = 0; i < markersAfterMove.length; i++) {
        print(
          'New marker ${i + 1}: ${markersAfterMove[i].latitude.toStringAsFixed(6)}, ${markersAfterMove[i].longitude.toStringAsFixed(6)}',
        );
      }

      // Verify markers were regenerated (positions should be different)
      bool markersChanged = false;
      if (initialMarkers.length == markersAfterMove.length) {
        for (int i = 0; i < initialMarkers.length; i++) {
          if (initialMarkers[i].latitude != markersAfterMove[i].latitude ||
              initialMarkers[i].longitude != markersAfterMove[i].longitude) {
            markersChanged = true;
            break;
          }
        }
      } else {
        markersChanged = true; // Different number of markers
      }

      expect(
        markersChanged,
        isTrue,
        reason:
            'Distance markers should be regenerated when waypoints are moved',
      );

      print('\nTest result: ${markersChanged ? "PASS" : "FAIL"}');
      print('Expected: Markers should be repositioned after waypoint move');
      print(
        'Actual: Markers ${markersChanged ? "were" : "were NOT"} repositioned',
      );
    });
  });
}
