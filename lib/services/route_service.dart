import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_route.dart';

/// Service for managing saved routes functionality
class RouteService {
  static const int maxSavedRoutes = 5;
  final Distance _distance = const Distance();

  /// Load saved routes from local storage
  Future<List<SavedRoute>> loadSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList('saved_routes') ?? [];
    final routes = <SavedRoute>[];

    for (final routeJson in routesJson) {
      try {
        final route = SavedRoute.fromJson(json.decode(routeJson));
        routes.add(route);
      } catch (e) {
        debugPrint('Error loading saved route: $e');
      }
    }

    return routes;
  }

  /// Save routes list to local storage
  Future<void> saveSavedRoutes(List<SavedRoute> routes) async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = routes
        .map((route) => json.encode(route.toJson()))
        .toList();
    await prefs.setStringList('saved_routes', routesJson);
  }

  /// Save current route with given name
  Future<SavedRoute> saveCurrentRoute({
    required String name,
    required List<LatLng> routePoints,
    required bool loopClosed,
  }) async {
    if (routePoints.isEmpty) {
      throw Exception('Ingen rutt att spara');
    }

    final newRoute = SavedRoute(
      name: name,
      points: List.from(routePoints),
      loopClosed: loopClosed,
      savedAt: DateTime.now(),
    );

    return newRoute;
  }

  /// Add route to saved routes list (manages max limit)
  List<SavedRoute> addRouteToSaved(
    List<SavedRoute> savedRoutes,
    SavedRoute newRoute,
  ) {
    final updatedRoutes = List<SavedRoute>.from(savedRoutes);

    // Remove oldest route if we're at the limit
    if (updatedRoutes.length >= maxSavedRoutes) {
      updatedRoutes.removeAt(0);
    }

    updatedRoutes.add(newRoute);
    return updatedRoutes;
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

  /// Remove route at specified index
  List<SavedRoute> removeRouteAt(List<SavedRoute> savedRoutes, int index) {
    final updatedRoutes = List<SavedRoute>.from(savedRoutes);
    updatedRoutes.removeAt(index);
    return updatedRoutes;
  }
}
