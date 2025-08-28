import 'package:flutter_test/flutter_test.dart';

// Distance formatting utility function (mirrors the one in DistanceMarkersLayer)
String formatDistanceLabel(double distanceKm) {
  if (distanceKm < 1.0) {
    return '${(distanceKm * 1000).round()}m';
  } else if (distanceKm % 1 == 0) {
    return distanceKm.toInt().toString();
  } else {
    return distanceKm.toString();
  }
}

void main() {
  group('Distance Markers with Labels', () {
    test('should format distance labels correctly for kilometers', () {
      expect(formatDistanceLabel(1.0), equals('1'));
      expect(formatDistanceLabel(2.0), equals('2'));
      expect(formatDistanceLabel(10.0), equals('10'));
      expect(formatDistanceLabel(100.0), equals('100'));
    });

    test('should format distance labels correctly for decimal kilometers', () {
      expect(formatDistanceLabel(1.5), equals('1.5'));
      expect(formatDistanceLabel(2.3), equals('2.3'));
      expect(formatDistanceLabel(5.7), equals('5.7'));
      expect(formatDistanceLabel(10.25), equals('10.25'));
    });

    test(
      'should format distance labels correctly for sub-kilometer distances',
      () {
        expect(formatDistanceLabel(0.5), equals('500m'));
        expect(formatDistanceLabel(0.25), equals('250m'));
        expect(formatDistanceLabel(0.75), equals('750m'));
        expect(formatDistanceLabel(0.1), equals('100m'));
        expect(formatDistanceLabel(0.05), equals('50m'));
      },
    );

    test('should handle edge cases', () {
      expect(formatDistanceLabel(0.0), equals('0m'));
      expect(formatDistanceLabel(0.001), equals('1m'));
      expect(formatDistanceLabel(0.999), equals('999m'));
      expect(formatDistanceLabel(1.00001), equals('1.00001'));
    });

    test('should validate distance marker data structure', () {
      // Test that the expected data structure works as expected
      final distanceMarkers = [
        (null, 1.0), // LatLng position, distance in km
        (null, 2.5),
        (null, 0.5),
      ];

      expect(distanceMarkers.length, equals(3));
      expect(distanceMarkers[0].$2, equals(1.0));
      expect(distanceMarkers[1].$2, equals(2.5));
      expect(distanceMarkers[2].$2, equals(0.5));

      // Test formatting for each
      expect(formatDistanceLabel(distanceMarkers[0].$2), equals('1'));
      expect(formatDistanceLabel(distanceMarkers[1].$2), equals('2.5'));
      expect(formatDistanceLabel(distanceMarkers[2].$2), equals('500m'));
    });
  });
}
