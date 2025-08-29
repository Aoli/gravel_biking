import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/models/saved_route.dart';
import 'package:gravel_biking/services/route_service.dart';
import 'package:gravel_biking/services/synced_route_service.dart';
import 'package:gravel_biking/services/route_cloud_service.dart';
import 'package:latlong2/latlong.dart';
import '../helpers/test_helpers.dart';

// Minimal in-memory fake for RouteCloudService to avoid Firebase in tests
class _FakeCloud implements RouteCloudService {
  final Map<String, SavedRoute> _byId = {};
  int _id = 0;

  @override
  Future<void> deleteRoute(String firestoreId) async {
    _byId.remove(firestoreId);
  }

  @override
  Future<List<SavedRoute>> getAllAccessibleRoutes(String userId) async {
    return _byId.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<List<SavedRoute>> getPublicRoutes({int limit = 50}) async {
    return _byId.values.where((r) => r.isPublic).toList();
  }

  @override
  Future<List<SavedRoute>> getUserRoutes(String userId) async {
    return _byId.values.where((r) => r.userId == userId).toList();
  }

  @override
  Future<List<SavedRoute>> searchPublicRoutes(String query) async {
    final q = query.toLowerCase();
    return _byId.values
        .where((r) => r.isPublic && r.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<SavedRoute> saveRoute(SavedRoute route) async {
    String id = route.firestoreId ?? (++_id).toString();
    final updated = route.copyWith(firestoreId: id, lastSynced: DateTime.now());
    _byId[id] = updated;
    return updated;
  }

  @override
  Stream<List<SavedRoute>> streamPublicRoutes({int limit = 50}) async* {
    yield await getPublicRoutes(limit: limit);
  }

  @override
  Stream<List<SavedRoute>> streamUserRoutes(String userId) async* {
    yield await getUserRoutes(userId);
  }

  @override
  Future<void> updateRouteVisibility(String firestoreId, bool isPublic) async {
    final r = _byId[firestoreId];
    if (r != null) {
      _byId[firestoreId] = r.copyWith(isPublic: isPublic);
    }
  }
}

void main() {
  group('Autosave create/overwrite behavior (service-level)', () {
    late RouteService routeService;
    late SyncedRouteService synced;
    late RouteCloudService fakeCloud;

    setUp(() async {
      // Local storage only; no cloud sync when userId == null
      routeService = RouteService();
      await routeService.initialize();
      // Ensure clean storage between tests
      await routeService.resetStorage();
      fakeCloud = _FakeCloud();
      synced = SyncedRouteService(
        localService: routeService,
        cloudService: fakeCloud,
        userId: null, // ensure cloud is not used
      );
    });

    tearDown(() async {
      await routeService.dispose();
    });

    test(
      'creates a private route when none exists (autosave create)',
      () async {
        const name = 'Autosave Test 1';

        // Precondition: no route with this name
        final preExisting = await synced.findRouteByName(name);
        expect(preExisting, isNull);

        // Simulate autosave create
        final created = await synced.saveCurrentRoute(
          name: name,
          routePoints: TestData.sampleRoutePoints,
          loopClosed: false,
          isPublic: false, // autosave always private
        );

        // Verify created
        expect(created.name, name);
        expect(created.isPublic, isFalse);

        // Route should be persisted locally
        final all = await routeService.loadSavedRoutes();
        expect(all.length, 1);
        expect(all.first.name, name);
      },
    );

    test(
      'overwrites existing route with same name (autosave overwrite)',
      () async {
        const name = 'Autosave Test 2';

        // Initial create (simulating first autosave tick)
        final first = await synced.saveCurrentRoute(
          name: name,
          routePoints: TestData.sampleRoutePoints,
          loopClosed: false,
          isPublic: false,
        );

        // Find by name (like autosave would do)
        final existing = await synced.findRouteByName(name);
        expect(existing, isNotNull);

        // Prepare updated points and loop flag
        final updatedPoints = <LatLng>[
          ...TestData.sampleRoutePoints,
          const LatLng(59.3100, 18.0900),
        ];

        // Simulate autosave overwrite tick using the existing route reference
        await synced.overwriteRoute(
          existingRoute: existing!,
          routePoints: updatedPoints,
          loopClosed: true,
          isPublic: false, // autosave keeps it private
        );

        // Still only one route stored
        final count = await routeService.getRouteCount();
        expect(count, 1);

        // Verify overwrite preserved name and savedAt, but updated points/loopClosed
        final after = await routeService.loadSavedRoutes();
        expect(after.length, 1);
        final r = after.first;
        expect(r.name, name);
        expect(
          r.savedAt,
          first.savedAt,
          reason: 'savedAt should be preserved on overwrite',
        );
        expect(r.loopClosed, isTrue);
        expect(r.points.length, updatedPoints.length);
      },
    );
  });
}
