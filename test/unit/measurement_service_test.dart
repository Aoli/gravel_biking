import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gravel_biking/services/measurement_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('MeasurementService', () {
    late MeasurementService service;

    setUp(() {
      service = MeasurementService();
    });

    group('initialization', () {
      test('should initialize with default values', () {
        expect(service.routePoints, isEmpty);
        expect(service.segmentMeters, isEmpty);
        expect(service.distanceMarkers, isEmpty);
        expect(service.measureEnabled, isFalse);
        expect(service.loopClosed, isFalse);
        expect(service.editModeEnabled, isFalse);
        expect(service.editingIndex, isNull);
        expect(service.showDistanceMarkers, isTrue);
        expect(service.distanceInterval, equals(1.0));
      });
    });

    group('route point management', () {
      test('should add route points correctly', () {
        const point1 = TestData.sampleCoordinate;
        const point2 = LatLng(59.3344, 18.0632);

        service.addRoutePoint(point1);
        expect(service.routePoints, hasLength(1));
        expect(service.routePoints.first, CustomMatchers.closeTo(point1));

        service.addRoutePoint(point2);
        expect(service.routePoints, hasLength(2));
        expect(service.routePoints.last, CustomMatchers.closeTo(point2));
      });

      test('should reopen loop when adding point to closed loop', () {
        // Add points and close loop
        for (final point in TestData.sampleRoutePoints) {
          service.addRoutePoint(point);
        }
        service.toggleLoop(); // Close loop
        expect(service.loopClosed, isTrue);

        // Add new point should reopen loop
        service.addRoutePoint(const LatLng(60.0, 19.0));
        expect(service.loopClosed, isFalse);
      });

      test('should move route point correctly', () {
        service.addRoutePoint(TestData.sampleCoordinate);
        const newPosition = LatLng(60.0, 19.0);

        service.moveRoutePoint(0, newPosition);
        expect(service.routePoints.first, CustomMatchers.closeTo(newPosition));
      });

      test('should handle invalid move point index gracefully', () {
        service.addRoutePoint(TestData.sampleCoordinate);
        const newPosition = LatLng(60.0, 19.0);

        // Should not throw when index is out of bounds
        expect(() => service.moveRoutePoint(5, newPosition), returnsNormally);
        expect(
          service.routePoints.first,
          CustomMatchers.closeTo(TestData.sampleCoordinate),
        );
      });

      test('should delete route point correctly', () {
        for (final point in TestData.sampleRoutePoints) {
          service.addRoutePoint(point);
        }
        final originalLength = service.routePoints.length;

        service.deletePoint(1);
        expect(service.routePoints, hasLength(originalLength - 1));
        expect(
          service.routePoints[1],
          isNot(CustomMatchers.closeTo(TestData.sampleRoutePoints[1])),
        );
      });

      test('should handle invalid delete point index gracefully', () {
        service.addRoutePoint(TestData.sampleCoordinate);
        final originalLength = service.routePoints.length;

        // Should not throw when index is out of bounds
        expect(() => service.deletePoint(5), returnsNormally);
        expect(service.routePoints, hasLength(originalLength));
      });

      test('should add point between existing points correctly', () {
        service.addRoutePoint(const LatLng(59.0, 18.0));
        service.addRoutePoint(const LatLng(60.0, 18.0));
        final originalLength = service.routePoints.length;
        const midpoint = LatLng(59.5, 18.0);

        service.addPointBetween(0, 1, midpoint);
        expect(service.routePoints, hasLength(originalLength + 1));
        expect(service.routePoints[1], CustomMatchers.closeTo(midpoint));
      });

      test('should clear all route points', () {
        for (final point in TestData.sampleRoutePoints) {
          service.addRoutePoint(point);
        }
        service.toggleLoop(); // Close loop

        service.clearRoute();
        expect(service.routePoints, isEmpty);
        expect(service.segmentMeters, isEmpty);
        expect(service.loopClosed, isFalse);
        expect(service.distanceMarkers, isEmpty);
      });

      test('should load route points correctly', () {
        final routePoints = TestData.sampleRoutePoints;
        service.loadRoute(routePoints, loopClosed: true);

        expect(service.routePoints, hasLength(routePoints.length));
        expect(service.loopClosed, isTrue);
        for (int i = 0; i < routePoints.length; i++) {
          expect(
            service.routePoints[i],
            CustomMatchers.closeTo(routePoints[i]),
          );
        }
      });
    });

    group('loop management', () {
      setUp(() {
        for (final point in TestData.sampleRoutePoints) {
          service.addRoutePoint(point);
        }
      });

      test('should toggle loop correctly', () {
        expect(service.loopClosed, isFalse);

        service.toggleLoop();
        expect(service.loopClosed, isTrue);
        expect(
          service.segmentMeters.length,
          equals(service.routePoints.length),
        );

        service.toggleLoop();
        expect(service.loopClosed, isFalse);
        expect(
          service.segmentMeters.length,
          equals(service.routePoints.length - 1),
        );
      });

      test('should not toggle loop with less than 3 points', () {
        service.clearRoute();
        service.addRoutePoint(TestData.sampleCoordinate);
        service.addRoutePoint(const LatLng(60.0, 19.0));

        service.toggleLoop();
        expect(service.loopClosed, isFalse);
      });
    });

    group('distance calculations', () {
      setUp(() {
        for (final point in TestData.sampleRoutePoints) {
          service.addRoutePoint(point);
        }
      });

      test('should calculate distance to point correctly', () {
        final distanceToSecond = service.calculateDistanceToPoint(1);
        expect(distanceToSecond, greaterThan(0));

        final distanceToThird = service.calculateDistanceToPoint(2);
        expect(distanceToThird, greaterThan(distanceToSecond));
      });

      test('should handle invalid point index in distance calculation', () {
        expect(service.calculateDistanceToPoint(10), equals(0));
      });

      test('should calculate total distance from segments', () {
        expect(service.segmentMeters, isNotEmpty);
        final totalDistance = service.segmentMeters.fold(
          0.0,
          (sum, segment) => sum + segment,
        );
        expect(totalDistance, greaterThan(0));
      });

      test('should include loop segment when closed', () {
        final openSegments = service.segmentMeters.length;
        service.toggleLoop();
        final closedSegments = service.segmentMeters.length;

        expect(closedSegments, equals(openSegments + 1));
      });
    });

    group('distance markers', () {
      setUp(() {
        // Create a longer route for meaningful distance markers
        final longRoute = TestData.longRoute();
        service.loadRoute(longRoute.take(100).toList());
      });

      test('should generate distance markers', () {
        service.generateDistanceMarkers();
        expect(service.distanceMarkers, isNotEmpty);
        expect(service.showDistanceMarkers, isTrue);
      });

      test('should respect distance interval setting', () {
        service.distanceInterval = 2.0; // 2km intervals
        service.generateDistanceMarkers();

        // For the same route, 2km intervals should produce fewer markers than 1km
        final twoKmMarkers = service.distanceMarkers.length;

        service.distanceInterval = 1.0; // 1km intervals
        service.generateDistanceMarkers();
        final oneKmMarkers = service.distanceMarkers.length;

        expect(oneKmMarkers, greaterThanOrEqualTo(twoKmMarkers));
      });

      test('should handle empty route gracefully for markers', () {
        service.clearRoute();
        service.generateDistanceMarkers();
        expect(service.distanceMarkers, isEmpty);
      });

      test('should handle closed loop markers correctly', () {
        service.toggleLoop(); // Close the loop
        service.generateDistanceMarkers();
        expect(service.distanceMarkers, isNotEmpty);
      });
    });

    group('dynamic point sizing', () {
      test('should calculate dynamic point size based on route density', () {
        // Empty route
        service.clearRoute();
        expect(service.calculateDynamicPointSize(), equals(18.0));

        // Single point
        service.addRoutePoint(TestData.sampleCoordinate);
        expect(service.calculateDynamicPointSize(), equals(18.0));

        // Sparse route (should give larger markers)
        service.clearRoute();
        service.addRoutePoint(const LatLng(59.0, 18.0));
        service.addRoutePoint(const LatLng(60.0, 19.0)); // ~100km apart
        expect(service.calculateDynamicPointSize(), greaterThan(15.0));
      });
    });

    group('editing mode', () {
      test('should set edit mode correctly', () {
        service.editModeEnabled = true;
        expect(service.editModeEnabled, isTrue);

        service.editModeEnabled = false;
        expect(service.editModeEnabled, isFalse);
        expect(service.editingIndex, isNull);
      });

      test('should set editing index correctly', () {
        service.editingIndex = 2;
        expect(service.editingIndex, equals(2));

        service.editingIndex = null;
        expect(service.editingIndex, isNull);
      });

      test('should clear editing index when edit mode is disabled', () {
        service.editingIndex = 1;
        service.editModeEnabled = false;
        expect(service.editingIndex, isNull);
      });
    });

    group('measure mode', () {
      test('should toggle measure mode correctly', () {
        service.measureEnabled = true;
        expect(service.measureEnabled, isTrue);

        service.measureEnabled = false;
        expect(service.measureEnabled, isFalse);
      });
    });

    group('undo functionality', () {
      test('should undo last point addition', () {
        for (final point in TestData.sampleRoutePoints.take(3)) {
          service.addRoutePoint(point);
        }
        final originalLength = service.routePoints.length;

        service.undoLastPoint();
        expect(service.routePoints, hasLength(originalLength - 1));
      });

      test('should handle undo on empty route gracefully', () {
        expect(() => service.undoLastPoint(), returnsNormally);
        expect(service.routePoints, isEmpty);
      });

      test('should reopen loop when undoing results in less than 3 points', () {
        for (final point in TestData.sampleRoutePoints.take(3)) {
          service.addRoutePoint(point);
        }
        service.toggleLoop(); // Close loop with exactly 3 points

        service
            .undoLastPoint(); // This should reopen loop because < 3 points remain
        expect(service.loopClosed, isFalse);
      });
    });

    group('performance', () {
      test('should handle large routes efficiently', () {
        final longRoute = TestData.longRoute();

        final stopwatch = Stopwatch()..start();
        service.loadRoute(longRoute);
        stopwatch.stop();

        // Should complete loading 1000 points in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test(
        'should calculate distance markers for large routes efficiently',
        () {
          final longRoute = TestData.longRoute();
          service.loadRoute(longRoute);

          final stopwatch = Stopwatch()..start();
          service.generateDistanceMarkers();
          stopwatch.stop();

          expect(service.distanceMarkers, isNotEmpty);
          expect(stopwatch.elapsedMilliseconds, lessThan(50));
        },
      );
    });
  });
}
