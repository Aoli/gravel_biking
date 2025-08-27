import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_route.dart';

/// Enhanced service for managing saved routes with Hive storage
class RouteService {
  static const int maxSavedRoutes = 50;
  static const String _boxName = 'saved_routes';
  final Distance _distance = const Distance();
  Box<SavedRoute>? _routeBox;

  /// Initialize Hive storage
  Future<void> initialize() async {
    // Hive should already be initialized in main.dart, just open the box
    try {
      _routeBox = await Hive.openBox<SavedRoute>(_boxName);
      await _migrateFromSharedPreferences();
    } catch (e) {
      debugPrint('Error initializing RouteService: $e');
      rethrow;
    }
  }

  /// Get the Hive box (lazy initialization if needed)
  Future<Box<SavedRoute>> get _box async {
    if (_routeBox == null || !_routeBox!.isOpen) {
      await initialize();
    }
    return _routeBox!;
  }

  /// Load all saved routes
  Future<List<SavedRoute>> loadSavedRoutes() async {
    try {
      final box = await _box;
      return box.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (e) {
      debugPrint('Error loading saved routes: $e');
      return [];
    }
  }

  /// Search routes by name or description
  Future<List<SavedRoute>> searchRoutes(String query) async {
    try {
      final box = await _box;
      final allRoutes = box.values.toList();

      if (query.isEmpty) {
        return allRoutes..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      }

      final searchLower = query.toLowerCase();
      final filtered = allRoutes.where((route) {
        return route.name.toLowerCase().contains(searchLower) ||
            (route.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      return filtered..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (e) {
      debugPrint('Error searching routes: $e');
      return [];
    }
  }

  /// Save current route with enhanced metadata
  Future<SavedRoute> saveCurrentRoute({
    required String name,
    required List<LatLng> routePoints,
    required bool loopClosed,
    String? description,
  }) async {
    if (routePoints.isEmpty) {
      throw Exception('Ingen rutt att spara');
    }

    // Calculate total distance
    final segments = calculateSegmentDistances(
      routePoints: routePoints,
      loopClosed: loopClosed,
    );
    final totalDistance = segments.fold(0.0, (sum, segment) => sum + segment);

    final newRoute = SavedRoute.fromLatLng(
      name: name,
      latLngPoints: List.from(routePoints),
      loopClosed: loopClosed,
      savedAt: DateTime.now(),
      description: description,
      distance: totalDistance,
    );

    final box = await _box;

    // Remove oldest route if at capacity
    if (box.length >= maxSavedRoutes) {
      final oldestKey = box.keys.first;
      await box.delete(oldestKey);
    }

    await box.add(newRoute);
    return newRoute;
  }

  /// Delete route by key
  Future<void> deleteRoute(int key) async {
    try {
      final box = await _box;
      await box.delete(key);
    } catch (e) {
      debugPrint('Error deleting route: $e');
    }
  }

  /// Delete route by SavedRoute object
  Future<void> deleteRouteObject(SavedRoute route) async {
    try {
      final box = await _box;
      final key = route.key;
      if (key != null) {
        await box.delete(key);
      }
    } catch (e) {
      debugPrint('Error deleting route object: $e');
    }
  }

  /// Update route (replace existing route with new data)
  Future<void> updateRoute(SavedRoute oldRoute, SavedRoute newRoute) async {
    try {
      final box = await _box;

      // Find and delete the old route
      if (oldRoute.key != null) {
        await box.delete(oldRoute.key);
      }

      // Add the new route
      await box.add(newRoute);
    } catch (e) {
      debugPrint('Error updating route: $e');
      rethrow;
    }
  }

  /// Get routes count
  Future<int> getRouteCount() async {
    try {
      final box = await _box;
      return box.length;
    } catch (e) {
      debugPrint('Error getting route count: $e');
      return 0;
    }
  }

  /// Calculate segment distances for route points
  List<double> calculateSegmentDistances({
    required List<LatLng> routePoints,
    required bool loopClosed,
  }) {
    final segments = <double>[];

    // Calculate distances between consecutive points
    for (int i = 1; i < routePoints.length; i++) {
      segments.add(
        _distance.as(LengthUnit.Meter, routePoints[i - 1], routePoints[i]),
      );
    }

    // Add loop segment if the route is closed
    if (loopClosed && routePoints.length >= 3) {
      segments.add(
        _distance.as(LengthUnit.Meter, routePoints.last, routePoints.first),
      );
    }

    return segments;
  }

  /// Center map on route points
  void centerMapOnRoute({
    required MapController mapController,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.isEmpty) return;

    if (routePoints.length == 1) {
      mapController.move(routePoints.first, 15);
    } else {
      // Calculate bounds of all route points
      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;

      for (final point in routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      // Add padding around the route
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      mapController.fitCamera(CameraFit.bounds(bounds: bounds));
    }
  }

  /// Migrate from SharedPreferences to Hive (one-time migration)
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final box = await _box;
      if (box.isNotEmpty) return; // Already migrated

      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getStringList('saved_routes') ?? [];

      if (routesJson.isEmpty) return;

      debugPrint(
        'Migrating ${routesJson.length} routes from SharedPreferences to Hive',
      );

      for (final routeJson in routesJson) {
        try {
          final routeData = json.decode(routeJson);
          final route = SavedRoute.fromJson(routeData);
          await box.add(route);
        } catch (e) {
          debugPrint('Error migrating route: $e');
        }
      }

      // Clear old SharedPreferences data after successful migration
      await prefs.remove('saved_routes');
      debugPrint('Migration completed, SharedPreferences data cleared');
    } catch (e) {
      debugPrint('Error during migration: $e');
    }
  }

  /// Close Hive box when done (call in app disposal)
  Future<void> dispose() async {
    await _routeBox?.close();
  }
}
