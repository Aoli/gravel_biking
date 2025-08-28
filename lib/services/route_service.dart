import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  bool _storageDisabled = false; // Track if storage is completely disabled

  /// Initialize Hive storage with proper error handling and debugging
  Future<void> initialize() async {
    _log('Starting initialization...');
    try {
      // Skip adapter registration - they should already be registered in main()
      _log('Adapters already registered in main.dart');

      _log('Attempting to open Hive box "$_boxName"...');

      // Enhanced web environment handling for Android Chrome/WebView
      if (kIsWeb) {
        _log('Web runtime detected. Using IndexedDB backend for Hive.');
        // Open normally without an aggressive timeout. In some browsers a stale
        // or large IndexedDB can take longer to open and a timeout would cause
        // false negatives. If opening fails, attempt an automatic repair by
        // deleting the box and reopening once.
        try {
          _routeBox = await Hive.openBox<SavedRoute>(_boxName);
        } catch (openError) {
          _log('Open failed on web: $openError');
          _log(
            'Attempting automatic storage repair by deleting box and retrying...',
          );
          try {
            await Hive.deleteBoxFromDisk(_boxName);
            _log('Box deleted. Retrying open...');
            _routeBox = await Hive.openBox<SavedRoute>(_boxName);
          } catch (repairError, repairStack) {
            _log('Automatic repair failed: $repairError');
            _log('Repair stack: $repairStack');
            rethrow; // Let outer catch mark storage disabled
          }
        }
      } else {
        // Native platforms
        _routeBox = await Hive.openBox<SavedRoute>(_boxName);
      }

      _log('Hive box opened successfully (${_routeBox?.length ?? 0} routes)');
      _storageDisabled = false; // Storage is working
    } catch (e, s) {
      _log('CRITICAL: Hive initialization failed: $e');
      _log('Stack trace: ${s.toString()}');

      // Mark storage as disabled but don't throw - allow graceful degradation
      _storageDisabled = true;
      _routeBox = null;

      // For web environments, provide more specific error guidance
      if (kIsWeb) {
        _log('Web-specific troubleshooting:');
        _log('1. Check if browser storage is enabled');
        _log('2. Check if in incognito/private mode');
        _log('3. Check browser storage quota');
        _log('GRACEFUL DEGRADATION: App will continue without route saving');
      } else {
        _log('GRACEFUL DEGRADATION: App will continue without route saving');
      }

      // Don't throw - let the app continue with storage disabled
    }
  }

  /// Forcefully reset web storage by deleting the Hive box from disk and reopening it.
  /// Returns true on success. Safe to call only when storage is disabled or to
  /// recover from corrupted state on the web.
  Future<bool> resetStorage() async {
    try {
      _log('Resetting storage: closing and deleting box "$_boxName"...');
      await _routeBox?.close();
      _routeBox = null;
      await Hive.deleteBoxFromDisk(_boxName);
      _log('Reopening box after reset...');
      _routeBox = await Hive.openBox<SavedRoute>(_boxName);
      _storageDisabled = false;
      _log('Storage reset successful. Box length: ${_routeBox?.length ?? 0}');
      return true;
    } catch (e, s) {
      _log('Storage reset failed: $e');
      _log('Stack trace: $s');
      _storageDisabled = true;
      _routeBox = null;
      return false;
    }
  }

  Box<SavedRoute> get _box {
    if (_storageDisabled) {
      throw Exception(
        'Storage unavailable - may be disabled in private browsing mode',
      );
    }
    if (_routeBox == null || !_routeBox!.isOpen) {
      throw Exception(
        'RouteService not properly initialized. Hive box is not available.',
      );
    }
    return _routeBox!;
  }

  /// Load all saved routes
  Future<List<SavedRoute>> loadSavedRoutes() async {
    if (_storageDisabled) {
      debugPrint('Storage disabled - returning empty route list');
      return [];
    }
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
    if (_storageDisabled) {
      debugPrint('Storage disabled - returning empty search results');
      return [];
    }
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
    if (_storageDisabled) {
      throw Exception(
        'Storage unavailable. Route saving is disabled in private browsing mode or when browser storage is disabled.',
      );
    }

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
    if (_storageDisabled) {
      debugPrint('Storage disabled - cannot delete route');
      return;
    }
    try {
      final box = _box;
      await box.delete(key);
    } catch (e) {
      debugPrint('Error deleting route: $e');
    }
  }

  /// Delete route by SavedRoute object
  Future<void> deleteRouteObject(SavedRoute route) async {
    if (_storageDisabled) {
      debugPrint('Storage disabled - cannot delete route');
      return;
    }
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
    if (_storageDisabled) {
      throw Exception('Storage unavailable - cannot update route');
    }
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
    if (_storageDisabled) {
      return 0;
    }
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
    if (_storageDisabled) {
      return false;
    }
    final isAvailable = _routeBox != null && _routeBox!.isOpen;
    if (!isAvailable) {
      debugPrint(
        'RouteService: Storage not available - box null: ${_routeBox == null}, box open: ${_routeBox?.isOpen ?? false}',
      );
    }
    return isAvailable;
  }

  /// Get diagnostic information about the current storage state
  String getStorageDiagnostics() {
    return 'RouteService State: '
        'storage disabled=$_storageDisabled, '
        'box null=${_routeBox == null}, '
        'box open=${_routeBox?.isOpen ?? false}, '
        'box length=${_routeBox?.length ?? 'N/A'}';
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

  void _log(String message) {
    debugPrint('RouteService: $message');
  }
}
