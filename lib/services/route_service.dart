import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';

/// Enhanced service for managing saved routes with Hive storage
class RouteService {
  static const int maxSavedRoutes = 50;
  static const String _boxName = 'saved_routes';
  final Distance _distance = const Distance();
  Box<SavedRoute>? _routeBox;

  /// Initialize Hive storage with proper error handling and debugging
  Future<void> initialize() async {
    debugPrint('RouteService: Starting initialization...');

    // Check if Hive is initialized
    if (!Hive.isAdapterRegistered(0) || !Hive.isAdapterRegistered(1)) {
      debugPrint(
        'RouteService: Hive adapters not registered! Re-registering...',
      );
      try {
        Hive.registerAdapter(SavedRouteAdapter());
        Hive.registerAdapter(LatLngDataAdapter());
        debugPrint('RouteService: Adapters re-registered successfully');
      } catch (e) {
        debugPrint('RouteService: Error re-registering adapters: $e');
      }
    }

    try {
      debugPrint('RouteService: Attempting to open Hive box "$_boxName"...');
      _routeBox = await Hive.openBox<SavedRoute>(_boxName);
      debugPrint(
        'RouteService: Hive box opened successfully (${_routeBox!.length} routes)',
      );
    } catch (e) {
      debugPrint('RouteService: Error opening Hive box: $e');
      debugPrint('RouteService: Error type: ${e.runtimeType}');
      debugPrint('RouteService: Error details: ${e.toString()}');

      // Try clearing any corrupted box and reopening
      try {
        debugPrint('RouteService: Attempting to delete and recreate box...');
        await Hive.deleteBoxFromDisk(_boxName);
        await Future.delayed(const Duration(milliseconds: 200));
        _routeBox = await Hive.openBox<SavedRoute>(_boxName);
        debugPrint('RouteService: Box recreated successfully');
      } catch (retryError) {
        debugPrint('RouteService: Box recreation failed: $retryError');
        // This is a real initialization failure - rethrow to make it visible
        rethrow;
      }
    }
  }

  /// Get the Hive box (must be initialized first)
  Box<SavedRoute> get _box {
    if (_routeBox == null || !_routeBox!.isOpen) {
      throw Exception(
        'RouteService not properly initialized. Hive box is not available.',
      );
    }
    return _routeBox!;
  }

  /// Load all saved routes
  Future<List<SavedRoute>> loadSavedRoutes() async {
    try {
      final box = _box;
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
      final box = _box;
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

    final box = _box;

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
      final box = _box;
      await box.delete(key);
    } catch (e) {
      debugPrint('Error deleting route: $e');
    }
  }

  /// Delete route by SavedRoute object
  Future<void> deleteRouteObject(SavedRoute route) async {
    try {
      final box = _box;
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
      final box = _box;

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
      final box = _box;
      return box.length;
    } catch (e) {
      debugPrint('Error getting route count: $e');
      return 0;
    }
  }

  /// Check if storage is available
  bool isStorageAvailable() {
    return _routeBox != null && _routeBox!.isOpen;
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

  // SharedPreferences migration removed: Hive is the single source of truth.

  /// Close Hive box when done (call in app disposal)
  Future<void> dispose() async {
    await _routeBox?.close();
  }
}
