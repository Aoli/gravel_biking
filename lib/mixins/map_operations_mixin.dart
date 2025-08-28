/// Map Operations Mixin for Gravel Data Fetching
///
/// Provides map interaction functionality including viewport-based gravel data
/// fetching, retry mechanisms, and Overpass API integration with debouncing.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../providers/loading_providers.dart';

/// Mixin providing map operations and gravel data fetching
///
/// This mixin encapsulates all map-related operations including:
/// - Viewport-based data fetching with debouncing
/// - Overpass API integration for gravel road data
/// - Retry mechanisms for network resilience
/// - Map event handling and bounds management
///
/// **Features:**
/// - 500ms debouncing to prevent excessive API calls
/// - Exponential backoff retry strategy
/// - Viewport bounds caching to avoid duplicate requests
/// - Background JSON parsing for large datasets
mixin MapOperationsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  // Map operation state
  Timer? _viewportDebounceTimer;
  LatLngBounds? _lastFetchedBounds;

  /// Handle map events with debounced viewport fetching
  ///
  /// Implements viewport-based data fetching with 500ms debouncing to prevent
  /// excessive API calls during map navigation.
  void handleMapEvent(
    MapEvent event,
    Function(List<Polyline>) onGravelDataUpdated,
  ) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      queueViewportFetch(onGravelDataUpdated);
    }
  }

  /// Queue viewport fetch with debouncing
  ///
  /// Implements debouncing to prevent excessive API calls during rapid
  /// map movements. Only triggers fetch after 500ms of inactivity.
  void queueViewportFetch(Function(List<Polyline>) onGravelDataUpdated) {
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final bounds = getCurrentBounds();
        if (bounds != null) {
          fetchGravelForBounds(bounds, onGravelDataUpdated);
        }
      }
    });
  }

  /// Get current map viewport bounds
  ///
  /// This method should be implemented by the consuming widget to provide
  /// the current map bounds. It's left abstract to allow flexibility in
  /// how the map controller is accessed.
  LatLngBounds? getCurrentBounds();

  /// Fetch gravel road data for given bounds
  ///
  /// Fetches gravel road data from Overpass API for the specified bounds.
  /// Includes deduplication logic to avoid fetching the same area multiple times.
  Future<void> fetchGravelForBounds(
    LatLngBounds bounds,
    Function(List<Polyline>) onGravelDataUpdated,
  ) async {
    // Skip if already fetched this area (with some tolerance)
    if (_lastFetchedBounds != null &&
        _boundsContainedIn(bounds, _lastFetchedBounds!)) {
      return;
    }

    await fetchGravelWithRetry(bounds, onGravelDataUpdated);
    _lastFetchedBounds = bounds;
  }

  /// Check if bounds are contained within cached bounds (with tolerance)
  bool _boundsContainedIn(LatLngBounds bounds, LatLngBounds cachedBounds) {
    const tolerance = 0.001; // Small tolerance for bounds comparison
    return bounds.north <= cachedBounds.north + tolerance &&
        bounds.south >= cachedBounds.south - tolerance &&
        bounds.east <= cachedBounds.east + tolerance &&
        bounds.west >= cachedBounds.west - tolerance;
  }

  /// Fetch gravel data with retry mechanism
  ///
  /// Implements exponential backoff retry strategy for network resilience.
  /// Uses background JSON parsing for large datasets to prevent UI blocking.
  Future<void> fetchGravelWithRetry(
    LatLngBounds bounds,
    Function(List<Polyline>) onGravelDataUpdated,
  ) async {
    if (!mounted) return;

    const maxRetries = 3;
    const baseDelay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        ref.read(isLoadingProvider.notifier).state = true;

        final query = _buildOverpassQuery(bounds);
        final response = await http
            .post(
              Uri.parse('https://overpass-api.de/api/interpreter'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: query,
            )
            .timeout(const Duration(seconds: 30));

        if (!mounted) return;

        if (response.statusCode == 200) {
          // Parse JSON in background isolate for large datasets
          final data = await compute(json.decode, response.body);
          final polylines = await compute<Map<String, dynamic>, List<Polyline>>(
            _parseGravelData,
            data,
          );

          if (!mounted) return;
          onGravelDataUpdated(polylines);
          break; // Success - exit retry loop
        } else if (response.statusCode == 429) {
          // Rate limited - wait longer before retry
          final delay = Duration(seconds: baseDelay.inSeconds * (attempt + 2));
          debugPrint(
            'Rate limited, waiting ${delay.inSeconds}s before retry ${attempt + 1}',
          );
          await Future.delayed(delay);
        } else {
          throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        debugPrint('Attempt ${attempt + 1} failed: $e');

        if (attempt == maxRetries - 1) {
          // Final attempt failed
          if (!mounted) return;
          if (e.toString().contains('TimeoutException')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Timeout - prova att zooma in mer för mindre område',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fel vid laddning av grusvägar: $e'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;
        } else {
          // Wait before retry with exponential backoff
          final delay = Duration(
            seconds: baseDelay.inSeconds * math.pow(2, attempt).toInt(),
          );
          await Future.delayed(delay);
        }
      } finally {
        if (mounted) {
          ref.read(isLoadingProvider.notifier).state = false;
        }
      }
    }
  }

  /// Build Overpass API query for gravel roads
  String _buildOverpassQuery(LatLngBounds bounds) {
    return '''
[out:json][timeout:25];
(
  way[highway~"^(track|path|cycleway|footway|bridleway|unclassified|tertiary|secondary|primary|trunk|residential|service)\$"]
     [surface~"^(gravel|compacted|fine_gravel|pebblestone|ground|earth|dirt|grass|sand|unpaved|cobblestone)\$"]
     (${bounds.south},${bounds.west},${bounds.north},${bounds.east});
);
out geom;
''';
  }

  /// Dispose map operation resources
  void disposeMapOperations() {
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = null;
  }
}

/// Background isolate function for parsing gravel road data
///
/// Parses Overpass API response and converts ways to Flutter Map polylines.
/// Runs in background isolate to prevent UI blocking with large datasets.
List<Polyline> _parseGravelData(Map<String, dynamic> data) {
  final polylines = <Polyline>[];

  if (data['elements'] != null) {
    for (final element in data['elements']) {
      if (element['type'] == 'way' && element['geometry'] != null) {
        final coords = <LatLng>[];
        for (final node in element['geometry']) {
          coords.add(LatLng(node['lat'], node['lon']));
        }
        if (coords.length >= 2) {
          polylines.add(
            Polyline(
              points: coords,
              strokeWidth: 2.0,
              color: const Color(0xFF8BC34A).withValues(alpha: 0.7),
            ),
          );
        }
      }
    }
  }

  return polylines;
}
