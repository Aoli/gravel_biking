import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for handling device location functionality
class LocationService {
  /// Get current device location and center map on it
  Future<LatLng?> locateMe({
    required BuildContext context,
    required MapController mapController,
    double? lastZoom,
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!context.mounted) return null;
        _showLocationError(context, 'Positionstjänster är avaktiverade');
        return null;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!context.mounted) return null;
        _showLocationError(context, 'Positionstillstånd nekat');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (!context.mounted) return latLng;

      // Center the map on the located position
      final zoom = lastZoom ?? 14.0;
      mapController.move(latLng, zoom);

      return latLng;
    } catch (e) {
      if (!context.mounted) return null;
      _showLocationError(context, 'Kunde inte hämta position: $e');
      return null;
    }
  }

  /// Show location error message to user
  void _showLocationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
