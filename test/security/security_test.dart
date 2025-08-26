import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/services/measurement_service.dart';
import 'package:latlong2/latlong.dart';

/// Security-focused tests to ensure data integrity and secure operations
void main() {
  group('Security Tests', () {
    late MeasurementService measurementService;

    setUp(() {
      measurementService = MeasurementService();
    });

    /// Helper method to calculate total distance from segmentMeters
    double getTotalDistance(MeasurementService service) {
      return service.segmentMeters.fold(0.0, (sum, distance) => sum + distance);
    }

    group('Input Validation', () {
      test('should handle extreme coordinates gracefully', () {
        // Test with extreme but valid coordinates
        const northPole = LatLng(90.0, 0.0);
        const southPole = LatLng(-90.0, 0.0);
        const dateLine = LatLng(0.0, 180.0);
        const primeMeridian = LatLng(0.0, -180.0);

        expect(
          () => measurementService.addRoutePoint(northPole),
          returnsNormally,
        );
        expect(
          () => measurementService.addRoutePoint(southPole),
          returnsNormally,
        );
        expect(
          () => measurementService.addRoutePoint(dateLine),
          returnsNormally,
        );
        expect(
          () => measurementService.addRoutePoint(primeMeridian),
          returnsNormally,
        );
      });

      test('should handle coordinate precision properly', () {
        // Test with high precision coordinates
        const highPrecisionPoint = LatLng(
          59.334591123456789,
          18.063240987654321,
        );
        measurementService.addRoutePoint(highPrecisionPoint);

        final points = measurementService.routePoints;
        expect(points.length, 1);
        expect(
          points.first.latitude,
          closeTo(59.334591123456789, 0.0000000000001),
        );
        expect(
          points.first.longitude,
          closeTo(18.063240987654321, 0.0000000000001),
        );
      });
    });

    group('Data Integrity', () {
      test('should maintain coordinate precision', () {
        final testPoint = const LatLng(59.334591, 18.063240); // Stockholm
        measurementService.addRoutePoint(testPoint);

        final points = measurementService.routePoints;
        expect(points.length, 1);
        expect(points.first.latitude, closeTo(59.334591, 0.000001));
        expect(points.first.longitude, closeTo(18.063240, 0.000001));
      });

      test('should handle multiple identical points properly', () {
        final testPoint = const LatLng(59.334591, 18.063240);

        measurementService.addRoutePoint(testPoint);
        measurementService.addRoutePoint(testPoint); // Same point

        final points = measurementService.routePoints;
        expect(points.length, 2); // Should allow duplicate points
        expect(points.every((p) => p == testPoint), true);
      });

      test('should maintain loop state consistency', () {
        // Add points to create a route
        measurementService.addRoutePoint(const LatLng(59.334, 18.063));
        measurementService.addRoutePoint(const LatLng(59.335, 18.064));
        measurementService.addRoutePoint(const LatLng(59.336, 18.065));

        // Close the loop
        measurementService.toggleLoop();
        expect(measurementService.loopClosed, true);

        // Adding a point should reopen the loop
        measurementService.addRoutePoint(const LatLng(59.337, 18.066));
        expect(measurementService.loopClosed, false);
      });
    });

    group('Memory Safety', () {
      test('should handle large number of points without memory issues', () {
        // Add a reasonable number of points (simulate a long route)
        for (int i = 0; i < 1000; i++) {
          final lat = 59.0 + (i * 0.001);
          final lng = 18.0 + (i * 0.001);
          measurementService.addRoutePoint(LatLng(lat, lng));
        }

        final points = measurementService.routePoints;
        expect(points.length, 1000);
        expect(getTotalDistance(measurementService), greaterThan(0));
      });

      test('should clear resources properly', () {
        // Add some points
        measurementService.addRoutePoint(const LatLng(59.334591, 18.063240));
        measurementService.addRoutePoint(const LatLng(59.335000, 18.064000));

        expect(measurementService.routePoints.isNotEmpty, true);

        // Clear all points
        measurementService.clearRoute();
        expect(measurementService.routePoints.isEmpty, true);
        expect(getTotalDistance(measurementService), 0.0);
      });
    });

    group('Performance Security', () {
      test('should calculate distances efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Add multiple points
        final testPoints = [
          const LatLng(59.334591, 18.063240), // Stockholm
          const LatLng(59.335000, 18.064000),
          const LatLng(59.336000, 18.065000),
          const LatLng(59.337000, 18.066000),
        ];

        for (final point in testPoints) {
          measurementService.addRoutePoint(point);
        }

        final distance = getTotalDistance(measurementService);
        stopwatch.stop();

        // Should complete in reasonable time (less than 100ms for this test)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(distance, greaterThan(0));
      });

      test('should not cause excessive CPU usage with rapid operations', () {
        final stopwatch = Stopwatch()..start();

        // Simulate rapid user interactions
        for (int i = 0; i < 100; i++) {
          measurementService.addRoutePoint(
            LatLng(59.0 + i * 0.01, 18.0 + i * 0.01),
          );
          if (i % 10 == 0) {
            getTotalDistance(measurementService);
          }
        }

        stopwatch.stop();

        // Should handle rapid operations efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Error Handling Security', () {
      test('should handle operations on empty route gracefully', () {
        // Test operations on empty route
        expect(getTotalDistance(measurementService), 0.0);
        expect(measurementService.routePoints, isEmpty);

        // Test undo with no points
        expect(() => measurementService.undoLastPoint(), returnsNormally);

        // Test clearing empty route
        expect(() => measurementService.clearRoute(), returnsNormally);
      });

      test('should handle invalid edit operations gracefully', () {
        // Try to edit with no points
        expect(() => measurementService.editingIndex = 0, returnsNormally);

        // Add some points
        measurementService.addRoutePoint(const LatLng(59.334, 18.063));
        measurementService.addRoutePoint(const LatLng(59.335, 18.064));

        // Try to edit with invalid index
        expect(() => measurementService.editingIndex = -1, returnsNormally);
        expect(() => measurementService.editingIndex = 100, returnsNormally);
      });

      test('should maintain state consistency during error conditions', () {
        measurementService.measureEnabled = true;
        measurementService.editModeEnabled = true;

        // Add some points
        measurementService.addRoutePoint(const LatLng(59.334, 18.063));
        measurementService.addRoutePoint(const LatLng(59.335, 18.064));

        // Verify state is maintained
        expect(measurementService.measureEnabled, true);
        expect(measurementService.editModeEnabled, true);
        expect(measurementService.routePoints.length, 2);
      });
    });
  });
}
