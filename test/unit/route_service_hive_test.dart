import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/services/route_service.dart';
import 'package:latlong2/latlong.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('RouteService + Hive integration', () {
    late RouteService service;

    setUp(() async {
      // flutter_test_config.dart already initializes Hive and registers adapters.
      service = RouteService();
      await service.initialize();
      expect(service.isStorageAvailable(), isTrue);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('initialize opens box and reports zero routes initially', () async {
      final count = await service.getRouteCount();
      expect(count, equals(0));
    });

    test('save -> load -> search -> delete workflow', () async {
      final points = TestData.sampleRoutePoints;

      final saved = await service.saveCurrentRoute(
        name: 'R1',
        routePoints: points,
        loopClosed: false,
        description: 'desc',
      );

      expect(await service.getRouteCount(), equals(1));

      final all = await service.loadSavedRoutes();
      expect(all.length, 1);
      expect(all.first.name, 'R1');

      final found = await service.searchRoutes('r1');
      expect(found.length, 1);
      expect(found.first.name, 'R1');

      await service.deleteRouteObject(saved);
      expect(await service.getRouteCount(), equals(0));
    });

    test('update route replaces entry and keeps count', () async {
      final points = TestData.sampleRoutePoints;

      final oldRoute = await service.saveCurrentRoute(
        name: 'Old',
        routePoints: points,
        loopClosed: false,
      );
      expect(await service.getRouteCount(), 1);

      // Create a non-persisted replacement route
      final replacement = TestData.createSampleRoute(
        name: 'New',
        latLngPoints: List<LatLng>.from(points),
        loopClosed: true,
      );

      await service.updateRoute(oldRoute, replacement);

      final all = await service.loadSavedRoutes();
      expect(all.length, 1);
      expect(all.first.name, 'New');
      expect(all.first.loopClosed, isTrue);
    });

    test('FIFO eviction when exceeding maxSavedRoutes', () async {
      final max = RouteService.maxSavedRoutes;
      for (var i = 0; i < max + 5; i++) {
        await service.saveCurrentRoute(
          name: 'Route ${i + 1}',
          routePoints: TestData.sampleRoutePoints,
          loopClosed: i % 2 == 0,
        );
      }

      final count = await service.getRouteCount();
      expect(count, equals(max));

      final all = await service.loadSavedRoutes();
      // Oldest 5 should have been evicted; ensure a later one exists.
      expect(all.any((r) => r.name == 'Route 1'), isFalse);
      expect(all.any((r) => r.name == 'Route 6'), isTrue);
    });

    test('dispose closes box and marks storage unavailable', () async {
      await service.dispose();
      expect(service.isStorageAvailable(), isFalse);
    });

    test('calling save without initialize throws', () async {
      final fresh = RouteService();
      expect(
        () => fresh.saveCurrentRoute(
          name: 'X',
          routePoints: TestData.sampleRoutePoints,
          loopClosed: false,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
