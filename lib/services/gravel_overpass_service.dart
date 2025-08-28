import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/coordinate_utils.dart';

/// Service responsible for fetching gravel data from Overpass API
class GravelOverpassService {
  DateTime? _lastRateLimitError;
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _rateLimitCooldown = Duration(minutes: 1);

  /// Fetch polylines for given bounds with retry/backoff and cooldown handling.
  /// Returns null when skipped due to cooldown or when a non-retryable error occurs.
  Future<List<Polyline>?> fetchPolylinesForBounds(
    LatLngBounds bounds, {
    required String appVersion,
  }) async {
    final timestamp = DateTime.now();
    debugPrint('🌐 [${timestamp.toIso8601String()}] Gravel fetch requested');
    debugPrint(
      '📍 Bounds: ${bounds.southWest.latitude.toStringAsFixed(4)},${bounds.southWest.longitude.toStringAsFixed(4)} to ${bounds.northEast.latitude.toStringAsFixed(4)},${bounds.northEast.longitude.toStringAsFixed(4)}',
    );

    // Rate limit cooldown check
    if (_lastRateLimitError != null) {
      final timeSinceLastError = DateTime.now().difference(
        _lastRateLimitError!,
      );
      if (timeSinceLastError < _rateLimitCooldown) {
        final remainingSeconds =
            _rateLimitCooldown.inSeconds - timeSinceLastError.inSeconds;
        debugPrint(
          '⏸️  [${timestamp.toIso8601String()}] Gravel fetch SKIPPED - in rate limit cooldown (${remainingSeconds}s remaining of ${_rateLimitCooldown.inSeconds}s)',
        );
        return null;
      }
      debugPrint(
        '✅ [${timestamp.toIso8601String()}] Rate limit cooldown expired, clearing error state',
      );
      _lastRateLimitError = null;
      _retryAttempts = 0;
    }

    return _fetchWithRetry(bounds, appVersion: appVersion);
  }

  Future<List<Polyline>?> _fetchWithRetry(
    LatLngBounds bounds, {
    required String appVersion,
  }) async {
    final startTime = DateTime.now();
    debugPrint(
      '🚀 [${startTime.toIso8601String()}] Starting API request (attempt ${_retryAttempts + 1}/$_maxRetryAttempts)',
    );

    const url = 'https://overpass-api.de/api/interpreter';
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    final south = sw.latitude.toStringAsFixed(6);
    final west = sw.longitude.toStringAsFixed(6);
    final north = ne.latitude.toStringAsFixed(6);
    final east = ne.longitude.toStringAsFixed(6);
    final sb = StringBuffer()
      ..writeln('[out:json];')
      ..writeln(
        'way["highway"~"(residential|service|track|unclassified|road)"]["surface"="gravel"]($south, $west, $north, $east);',
      )
      ..writeln('out geom;');
    final query = sb.toString();

    debugPrint('📝 Query size: ${query.length} characters');
    debugPrint(
      '🌍 Area coverage: ~${((ne.latitude - sw.latitude) * (ne.longitude - sw.longitude) * 12100).toStringAsFixed(1)} km²',
    );

    try {
      final ua =
          'Gravel First${appVersion.isNotEmpty ? '/$appVersion' : ''} (+https://github.com/Aoli/gravel_biking)';
      debugPrint('📡 Making HTTP POST to $url');
      final res = await http
          .post(
            Uri.parse(url),
            body: {'data': query},
            headers: {'User-Agent': ua},
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint(
                '⏰ [${DateTime.now().toIso8601String()}] Request TIMEOUT after 30 seconds',
              );
              throw TimeoutException(
                'Request timeout after 30 seconds',
                const Duration(seconds: 30),
              );
            },
          );

      final responseTime = DateTime.now().difference(startTime);
      debugPrint(
        '📥 [${DateTime.now().toIso8601String()}] Response received: ${res.statusCode} (${responseTime.inMilliseconds}ms)',
      );

      if (res.statusCode == 200) {
        _retryAttempts = 0;
        debugPrint('✅ Success! Response size: ${res.body.length} bytes');
        debugPrint('🔄 Processing polylines with compute...');

        final processStart = DateTime.now();
        final lines = await compute(
          CoordinateUtils.extractPolylineCoords,
          res.body,
        );
        final processTime = DateTime.now().difference(processStart);
        debugPrint(
          '🏗️ Processed ${lines.length} polylines in ${processTime.inMilliseconds}ms',
        );

        final polys = <Polyline>[
          for (final pts in lines)
            Polyline(
              points: [for (final p in pts) LatLng(p[0], p[1])],
              color: Colors.brown,
              strokeWidth: 4,
            ),
        ];

        debugPrint('🎯 Created ${polys.length} polyline objects');
        return polys;
      } else if (res.statusCode == 429) {
        _lastRateLimitError = DateTime.now();
        _retryAttempts++;
        debugPrint(
          '🚫 [${DateTime.now().toIso8601String()}] RATE LIMITED (429) - attempt $_retryAttempts/$_maxRetryAttempts after ${responseTime.inMilliseconds}ms',
        );

        if (_retryAttempts < _maxRetryAttempts) {
          final delaySeconds = (1 << _retryAttempts);
          debugPrint(
            '⏳ [${DateTime.now().toIso8601String()}] Waiting ${delaySeconds}s before retry (exponential backoff)...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          return _fetchWithRetry(bounds, appVersion: appVersion);
        } else {
          debugPrint(
            '🛑 [${DateTime.now().toIso8601String()}] MAX RETRY ATTEMPTS REACHED! Entering cooldown period of ${_rateLimitCooldown.inMinutes} minutes.',
          );
          return null;
        }
      } else {
        final errorTime = DateTime.now();
        debugPrint(
          '❌ [${errorTime.toIso8601String()}] HTTP ERROR ${res.statusCode} after ${errorTime.difference(startTime).inMilliseconds}ms',
        );
        if (res.headers.containsKey('retry-after')) {
          debugPrint(
            '🔄 Server suggests retry after: ${res.headers['retry-after']}',
          );
        }
        if (res.body.isNotEmpty && res.body.length < 1000) {
          debugPrint('📄 Error response body: ${res.body}');
        }
        return null;
      }
    } catch (e) {
      final errorTime = DateTime.now();
      final errorDuration = errorTime.difference(startTime);
      if (e is TimeoutException) {
        debugPrint(
          '⏰ [${errorTime.toIso8601String()}] REQUEST TIMEOUT after ${errorDuration.inMilliseconds}ms: $e',
        );
      } else {
        debugPrint(
          '💥 [${errorTime.toIso8601String()}] EXCEPTION after ${errorDuration.inMilliseconds}ms: ${e.runtimeType} - $e',
        );
      }
      return null;
    }
  }
}
