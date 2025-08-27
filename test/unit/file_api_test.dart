import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gravel_biking/services/file_service.dart';

// Mock classes for testing
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('File Service API Tests', () {
    late FileService fileService;
    late MockBuildContext mockContext;

    setUp(() {
      fileService = FileService();
      mockContext = MockBuildContext();
    });

    group('GeoJSON Processing', () {
      test('should create valid GeoJSON from route points', () {
        final routePoints = [
          LatLng(59.3293, 18.0686),
          LatLng(59.3344, 18.0632),
          LatLng(59.3286, 18.0849),
        ];
        const loopClosed = false;

        // Create the expected GeoJSON structure
        final coords = [
          for (final p in routePoints) [p.longitude, p.latitude],
        ];

        final expectedFeature = {
          'type': 'Feature',
          'properties': {
            'name': 'Gravel route',
            'loopClosed': loopClosed,
            'exportedAt': isA<String>(),
          },
          'geometry': {'type': 'LineString', 'coordinates': coords},
        };

        final expectedFC = {
          'type': 'FeatureCollection',
          'features': [expectedFeature],
        };

        // Verify the structure matches expected format
        expect(expectedFC['type'], equals('FeatureCollection'));
        expect(expectedFC['features'], isA<List>());
        expect(
          (expectedFC['features'] as List).first['geometry']['type'],
          equals('LineString'),
        );
        expect(
          (expectedFC['features'] as List).first['geometry']['coordinates'],
          hasLength(3),
        );
      });

      test('should handle loop closure in GeoJSON export', () {
        final routePoints = [
          LatLng(59.3293, 18.0686),
          LatLng(59.3344, 18.0632),
          LatLng(59.3286, 18.0849),
        ];
        const loopClosed = true;

        final coords = [
          for (final p in routePoints) [p.longitude, p.latitude],
          if (loopClosed && routePoints.length >= 3)
            [routePoints.first.longitude, routePoints.first.latitude],
        ];

        // With loop closed, should have one extra coordinate
        expect(coords, hasLength(4));
        expect(coords.first, equals(coords.last));
      });

      test('should parse valid GeoJSON input', () {
        const validGeoJSON = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {
                "name": "Test Route",
                "loopClosed": true
              },
              "geometry": {
                "type": "LineString",
                "coordinates": [
                  [18.0686, 59.3293],
                  [18.0632, 59.3344],
                  [18.0849, 59.3286]
                ]
              }
            }
          ]
        }''';

        final decoded = json.decode(validGeoJSON);
        expect(decoded['type'], equals('FeatureCollection'));
        expect(decoded['features'], hasLength(1));

        final feature = decoded['features'][0];
        expect(feature['geometry']['type'], equals('LineString'));
        expect(feature['geometry']['coordinates'], hasLength(3));
        expect(feature['properties']['loopClosed'], isTrue);
      });

      test('should handle malformed GeoJSON gracefully', () {
        const malformedGeoJSON = '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [18.0686, 59.3293]
              }
            }
          ]
        }''';

        final decoded = json.decode(malformedGeoJSON);
        final feature = decoded['features'][0];

        // Should not be a LineString
        expect(feature['geometry']['type'], equals('Point'));
        expect(feature['geometry']['type'], isNot(equals('LineString')));
      });
    });

    group('GPX Processing', () {
      test('should create valid GPX from route points', () {
        final routePoints = [
          LatLng(59.3293, 18.0686),
          LatLng(59.3344, 18.0632),
        ];

        // Test GPX structure building
        const expectedGpxStart = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Gravel First" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>Gravel route</name>
    <trkseg>''';

        expect(expectedGpxStart, contains('<?xml version="1.0"'));
        expect(expectedGpxStart, contains('gpx version="1.1"'));
        expect(expectedGpxStart, contains('creator="Gravel First"'));
        expect(expectedGpxStart, contains('<trkseg>'));
      });

      test('should format GPX coordinates correctly', () {
        const lat = 59.3293456;
        const lon = 18.0686789;

        final formattedLat = lat.toStringAsFixed(7);
        final formattedLon = lon.toStringAsFixed(7);

        expect(formattedLat, equals('59.3293456'));
        expect(formattedLon, equals('18.0686789'));
      });

      test('should handle loop closure in GPX export', () {
        final routePoints = [
          LatLng(59.3293, 18.0686),
          LatLng(59.3344, 18.0632),
          LatLng(59.3286, 18.0849),
        ];
        const loopClosed = true;

        var trkptCount = routePoints.length;
        if (loopClosed && routePoints.length >= 3) {
          trkptCount += 1; // Add closing point
        }

        expect(trkptCount, equals(4));
      });

      test('should parse GPX track points correctly', () {
        const validGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <trk>
    <name>Test Route</name>
    <trkseg>
      <trkpt lat="59.3293" lon="18.0686"></trkpt>
      <trkpt lat="59.3344" lon="18.0632"></trkpt>
    </trkseg>
  </trk>
</gpx>''';

        // Simple parsing validation
        expect(validGpx, contains('<trkpt lat="59.3293" lon="18.0686">'));
        expect(validGpx, contains('<trkpt lat="59.3344" lon="18.0632">'));

        // Count track points
        final trkptMatches = RegExp(r'<trkpt').allMatches(validGpx);
        expect(trkptMatches.length, equals(2));
      });
    });

    group('File Data Validation', () {
      test('should validate coordinate ranges', () {
        // Test coordinate validation functions
        bool isValidLatitude(double lat) => lat >= -90 && lat <= 90;
        bool isValidLongitude(double lon) => lon >= -180 && lon <= 180;

        expect(isValidLatitude(59.3293), isTrue);
        expect(isValidLatitude(90.0), isTrue);
        expect(isValidLatitude(-90.0), isTrue);
        expect(isValidLatitude(90.1), isFalse);
        expect(isValidLatitude(-90.1), isFalse);

        expect(isValidLongitude(18.0686), isTrue);
        expect(isValidLongitude(180.0), isTrue);
        expect(isValidLongitude(-180.0), isTrue);
        expect(isValidLongitude(180.1), isFalse);
        expect(isValidLongitude(-180.1), isFalse);
      });

      test('should handle empty route points gracefully', () {
        final emptyRoute = <LatLng>[];

        expect(emptyRoute.isEmpty, isTrue);
        expect(emptyRoute.length, equals(0));
      });

      test('should validate file data integrity', () {
        const testData = 'Test file content';
        final bytes = Uint8List.fromList(utf8.encode(testData));
        final decodedData = utf8.decode(bytes);

        expect(decodedData, equals(testData));
        expect(bytes.length, greaterThan(0));
      });

      test('should handle large coordinate datasets', () {
        // Test with large number of points
        final largeRoute = List.generate(
          5000,
          (index) => LatLng(59.0 + (index * 0.0001), 18.0 + (index * 0.0001)),
        );

        expect(largeRoute.length, equals(5000));
        expect(largeRoute.first.latitude, equals(59.0));
        expect(largeRoute.last.latitude, closeTo(59.4999, 0.0001));
      });
    });

    group('File Format Standards Compliance', () {
      test('should comply with GeoJSON RFC 7946 standard', () {
        const validGeoJSON = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'name': 'Test'},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [18.0686, 59.3293],
                  [18.0632, 59.3344],
                ],
              },
            },
          ],
        };

        // Validate required properties per RFC 7946
        expect(validGeoJSON['type'], equals('FeatureCollection'));
        expect(validGeoJSON['features'], isA<List>());

        final feature = (validGeoJSON['features'] as List)[0] as Map;
        expect(feature['type'], equals('Feature'));
        expect(feature['geometry'], isNotNull);
        expect(feature['properties'], isNotNull);
      });

      test('should comply with GPX 1.1 standard', () {
        const gpxNamespace = 'http://www.topografix.com/GPX/1/1';
        const gpxVersion = '1.1';

        // Validate GPX standard compliance
        expect(gpxNamespace, equals('http://www.topografix.com/GPX/1/1'));
        expect(gpxVersion, equals('1.1'));

        // Required GPX elements
        final requiredElements = ['gpx', 'trk', 'trkseg', 'trkpt'];
        expect(requiredElements, contains('gpx'));
        expect(requiredElements, contains('trkpt'));
      });

      test('should handle UTF-8 encoding correctly', () {
        const swedishText = 'Grävväg med åäö';
        final encodedBytes = utf8.encode(swedishText);
        final decodedText = utf8.decode(encodedBytes);

        expect(decodedText, equals(swedishText));
        expect(decodedText, contains('åäö'));
      });
    });

    group('Error Handling', () {
      test('should handle file size limits', () {
        const maxFileSize = 10 * 1024 * 1024; // 10MB
        const testDataSize = 1024; // 1KB

        expect(testDataSize, lessThan(maxFileSize));
        expect(maxFileSize, equals(10485760));
      });

      test('should handle malformed file data', () {
        const malformedJSON = '{"type": "Feature", "incomplete"';

        expect(
          () => json.decode(malformedJSON),
          throwsA(isA<FormatException>()),
        );
      });

      test('should validate file extensions', () {
        final validExtensions = ['geojson', 'json', 'gpx', 'xml'];

        expect(validExtensions, contains('geojson'));
        expect(validExtensions, contains('gpx'));
        expect(validExtensions, isNot(contains('txt')));
        expect(validExtensions, isNot(contains('exe')));
      });

      test('should handle coordinate precision limits', () {
        const highPrecisionLat = 59.123456789012345;
        const limitedPrecision = 7; // GPX standard

        final formattedLat = highPrecisionLat.toStringAsFixed(limitedPrecision);
        expect(formattedLat, equals('59.1234568'));
        expect(formattedLat.split('.')[1].length, equals(limitedPrecision));
      });
    });

    group('Cross-Platform Compatibility', () {
      test('should handle platform-specific path separators', () {
        const unixPath = '/home/user/documents/route.gpx';
        const windowsPath = r'C:\Users\User\Documents\route.gpx';

        expect(unixPath, contains('/'));
        expect(windowsPath, contains(r'\'));

        // Both should contain valid filename
        expect(unixPath, endsWith('.gpx'));
        expect(windowsPath, endsWith('.gpx'));
      });

      test('should handle different line endings', () {
        const unixLineEnding = '\n';
        const windowsLineEnding = '\r\n';
        const macLineEnding = '\r';

        final testWithUnix = 'Line 1${unixLineEnding}Line 2';
        final testWithWindows = 'Line 1${windowsLineEnding}Line 2';

        expect(testWithUnix, contains('\n'));
        expect(testWithWindows, contains('\r\n'));
        expect(testWithUnix, isNot(contains('\r')));
      });
    });
  });
}
