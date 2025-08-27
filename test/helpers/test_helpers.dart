// Test helpers and utilities for Gravel First testing
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:gravel_biking/models/saved_route.dart';

/// Mock data for testing
class TestData {
  /// Sample coordinate for testing
  static const LatLng sampleCoordinate = LatLng(59.3293, 18.0686); // Stockholm

  /// Sample route points for testing
  static const List<LatLng> sampleRoutePoints = [
    LatLng(59.3293, 18.0686), // Stockholm
    LatLng(59.3344, 18.0632), // Gamla Stan
    LatLng(59.3286, 18.0849), // Östermalm
    LatLng(59.3251, 18.0711), // Södermalm
  ];

  /// Sample closed loop route
  static const List<LatLng> sampleLoopRoute = [
    LatLng(59.3293, 18.0686),
    LatLng(59.3344, 18.0632),
    LatLng(59.3286, 18.0849),
    LatLng(59.3251, 18.0711),
    LatLng(59.3293, 18.0686), // Closes the loop
  ];

  /// Sample long route for performance testing
  static List<LatLng> longRoute() {
    final points = <LatLng>[];
    for (int i = 0; i < 1000; i++) {
      points.add(LatLng(59.3293 + (i * 0.001), 18.0686 + (i * 0.001)));
    }
    return points;
  }

  /// Create a sample SavedRoute for testing
  static SavedRoute createSampleRoute({
    String name = 'Test Route',
    String description = 'Test route description',
    bool loopClosed = false,
    List<LatLng>? latLngPoints,
  }) {
    return SavedRoute.fromLatLng(
      name: name,
      latLngPoints: latLngPoints ?? sampleRoutePoints,
      loopClosed: loopClosed,
      description: description,
    );
  }

  /// Create multiple sample routes for testing
  static List<SavedRoute> createSampleRoutes(int count) {
    return List.generate(
      count,
      (index) => createSampleRoute(
        name: 'Test Route ${index + 1}',
        description: 'Test route ${index + 1} description',
        loopClosed: index % 2 == 0, // Alternate between loop and linear
      ),
    );
  }

  /// Sample GeoJSON data for testing
  static const String sampleGeoJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [18.0686, 59.3293],
          [18.0632, 59.3344],
          [18.0849, 59.3286],
          [18.0711, 59.3251]
        ]
      },
      "properties": {
        "loopClosed": false,
        "name": "Test Route"
      }
    }
  ]
}''';

  /// Sample GPX data for testing
  static const String sampleGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Gravel First">
  <trk>
    <name>Test Route</name>
    <trkseg>
      <trkpt lat="59.3293" lon="18.0686"></trkpt>
      <trkpt lat="59.3344" lon="18.0632"></trkpt>
      <trkpt lat="59.3286" lon="18.0849"></trkpt>
      <trkpt lat="59.3251" lon="18.0711"></trkpt>
    </trkseg>
  </trk>
</gpx>''';

  /// Sample Overpass API response for testing
  static const String sampleOverpassResponse = '''
{
  "version": 0.6,
  "generator": "Overpass API 0.7.60.3",
  "elements": [
    {
      "type": "way",
      "id": 123456,
      "nodes": [1, 2, 3],
      "tags": {
        "highway": "track",
        "surface": "gravel"
      },
      "geometry": [
        {"lat": 59.3293, "lon": 18.0686},
        {"lat": 59.3344, "lon": 18.0632},
        {"lat": 59.3286, "lon": 18.0849}
      ]
    }
  ]
}''';
}

/// Test utilities for common operations
class TestUtils {
  /// Setup Hive for testing with temporary directory
  static Future<Directory> setupHiveForTest() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SavedRouteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LatLngDataAdapter());
    }
    
    return tempDir;
  }

  /// Clean up Hive after testing
  static Future<void> cleanupHiveAfterTest(Directory tempDir) async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (e) {
      // Ignore cleanup errors in test environment
    }
  }

  /// Creates a test MaterialApp wrapper for widget testing
  static Widget createTestApp(Widget child) {
    return MaterialApp(
      title: 'Gravel First Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: child,
    );
  }

  /// Pumps a widget with proper setup for testing
  static Future<void> pumpTestWidget(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    await tester.pumpWidget(createTestApp(widget));
    if (duration != null) {
      await tester.pump(duration);
    }
  }

  /// Waits for all animations and transitions to complete
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(timeout);
  }

  /// Finds a widget by its key
  static Finder findByKey(String key) {
    return find.byKey(Key(key));
  }

  /// Finds a widget by its text content
  static Finder findByText(String text) {
    return find.text(text);
  }

  /// Finds a widget by its type
  static Finder findByType<T>() {
    return find.byType(T);
  }

  /// Simulates a tap on a widget
  static Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }

  /// Simulates a long press on a widget
  static Future<void> longPress(WidgetTester tester, Finder finder) async {
    await tester.longPress(finder);
    await tester.pump();
  }

  /// Simulates entering text in a text field
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pump();
  }

  /// Waits for a specific widget to appear
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle();

    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (tester.any(finder)) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    throw TimeoutException('Widget not found within timeout', timeout);
  }

  /// Verifies that a widget exists and is visible
  static void expectWidgetVisible(Finder finder) {
    expect(finder, findsOneWidget);
  }

  /// Verifies that multiple widgets exist
  static void expectWidgets(Finder finder, int count) {
    expect(finder, findsNWidgets(count));
  }

  /// Verifies that no widget is found
  static void expectNoWidget(Finder finder) {
    expect(finder, findsNothing);
  }
}

/// Mock implementations for testing
class MockData {
  /// Mock GPS coordinates for different scenarios
  static const Map<String, LatLng> locations = {
    'stockholm': LatLng(59.3293, 18.0686),
    'goteborg': LatLng(57.7089, 11.9746),
    'malmo': LatLng(55.6050, 13.0038),
    'invalid': LatLng(999.0, 999.0),
  };

  /// Mock network responses for different scenarios
  static const Map<String, String> networkResponses = {
    'success': TestData.sampleOverpassResponse,
    'empty': '{"elements": []}',
    'error': '{"error": "timeout"}',
  };

  /// Mock file content for different formats
  static const Map<String, String> fileContents = {
    'geojson': TestData.sampleGeoJson,
    'gpx': TestData.sampleGpx,
    'invalid': 'invalid content',
  };
}

/// Performance testing utilities
class PerformanceUtils {
  /// Measures the execution time of a function
  static Future<Duration> measureExecutionTime(
    Future<void> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Measures the execution time of a synchronous function
  static Duration measureSyncExecutionTime(void Function() action) {
    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Creates a memory usage measurement
  static int getCurrentMemoryUsage() {
    // In a real implementation, this would measure actual memory usage
    // For testing purposes, we'll return a mock value
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  /// Verifies performance meets expectations
  static void expectPerformance(
    Duration actual,
    Duration expected, {
    String? reason,
  }) {
    expect(
      actual.inMilliseconds,
      lessThanOrEqualTo(expected.inMilliseconds),
      reason:
          reason ??
          'Performance expectation failed: ${actual.inMilliseconds}ms > ${expected.inMilliseconds}ms',
    );
  }
}

/// Custom matchers for testing
class CustomMatchers {
  /// Matcher for LatLng coordinates within tolerance
  static Matcher closeTo(LatLng expected, {double tolerance = 0.001}) {
    return _CoordinateMatcher(expected, tolerance);
  }

  /// Matcher for route distances within tolerance
  static Matcher distanceCloseTo(double expected, {double tolerance = 0.1}) {
    return inInclusiveRange(expected - tolerance, expected + tolerance);
  }
}

class _CoordinateMatcher extends Matcher {
  final LatLng expected;
  final double tolerance;

  _CoordinateMatcher(this.expected, this.tolerance);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! LatLng) return false;

    final latDiff = (item.latitude - expected.latitude).abs();
    final lngDiff = (item.longitude - expected.longitude).abs();

    return latDiff <= tolerance && lngDiff <= tolerance;
  }

  @override
  Description describe(Description description) {
    return description.add('coordinates close to $expected within $tolerance');
  }
}
