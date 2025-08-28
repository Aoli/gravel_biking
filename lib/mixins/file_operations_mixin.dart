/// File Operations Mixin for Route Import/Export
///
/// Provides file import and export functionality for GPX and GeoJSON formats.
/// This mixin handles all file picker operations, format conversion, and
/// user feedback for route file operations.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart' as xml;

import '../providers/loading_providers.dart';
import '../providers/ui_providers.dart';
import '../utils/gpx_utils.dart';

/// Mixin providing file import/export operations for route data
///
/// This mixin encapsulates all file operations related to route import and export,
/// including GPX and GeoJSON format support, file picker integration, and
/// background processing for large files.
///
/// **Supported Operations:**
/// - GPX import with background processing and smart decimation
/// - GPX export with loop closure handling
/// - GeoJSON import with coordinate validation
/// - GeoJSON export with metadata
///
/// **Requirements:**
/// - Must be mixed with a ConsumerStatefulWidget
/// - Requires access to route state via providers
/// - Requires mounted context for UI feedback
mixin FileOperationsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Export current route as GeoJSON format
  ///
  /// Creates a GeoJSON FeatureCollection with route metadata and coordinates.
  /// Handles loop closure by adding closing coordinate if necessary.
  Future<void> exportGeoJsonRoute(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att exportera')));
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;

    try {
      final coords = [
        for (final p in routePoints) [p.longitude, p.latitude],
        if (ref.read(loopClosedProvider) && routePoints.length >= 3)
          [routePoints.first.longitude, routePoints.first.latitude],
      ];

      final feature = {
        'type': 'Feature',
        'properties': {
          'name': 'Gravel route',
          'loopClosed': ref.read(loopClosedProvider),
          'exportedAt': DateTime.now().toIso8601String(),
        },
        'geometry': {'type': 'LineString', 'coordinates': coords},
      };

      final fc = {
        'type': 'FeatureCollection',
        'features': [feature],
      };

      final content = const JsonEncoder.withIndent('  ').convert(fc);
      final bytes = Uint8List.fromList(utf8.encode(content));

      await FileSaver.instance.saveFile(
        name: 'gravel_route_${DateTime.now().millisecondsSinceEpoch}.geojson',
        bytes: bytes,
        ext: 'geojson',
        mimeType: MimeType.json,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Rutt exporterad som GeoJSON',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export misslyckades: $e')));
    } finally {
      if (mounted) {
        ref.read(isExportingProvider.notifier).state = false;
      }
    }
  }

  /// Import route from GeoJSON file
  ///
  /// Handles GeoJSON LineString parsing and coordinate extraction.
  /// Detects loop closure from geometry properties.
  Future<void> importGeoJsonRoute(
    Function(List<LatLng> points, bool loopClosed) onRouteImported,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['geojson', 'json'],
        withData: true,
      );

      if (result?.files.single.bytes == null) return;
      final bytes = result!.files.single.bytes!;
      final text = utf8.decode(bytes);
      final data = json.decode(text);

      List<LatLng>? coords;
      bool loopClosed = false;

      if (data['type'] == 'FeatureCollection' && data['features'] is List) {
        final features = data['features'] as List;
        for (final feature in features) {
          if (feature['geometry']?['type'] == 'LineString') {
            final coordList = feature['geometry']['coordinates'] as List;
            coords = coordList
                .cast<List>()
                .map((c) => LatLng(c[1] as double, c[0] as double))
                .toList();

            // Check for loop closure property or geometric closure
            final props = feature['properties'] as Map?;
            loopClosed =
                props?['loopClosed'] == true ||
                (coords.length >= 3 && coords.first == coords.last);

            if (loopClosed &&
                coords.isNotEmpty &&
                coords.first == coords.last) {
              coords.removeLast(); // Remove duplicate closing point
            }
            break;
          }
        }
      }

      if (coords == null || coords.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingen giltig LineString hittad i GeoJSON'),
          ),
        );
        return;
      }

      onRouteImported(coords, loopClosed);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GeoJSON importerad: ${coords.length} punkter'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import misslyckades: $e')));
    }
  }

  /// Export current route as GPX format
  ///
  /// Creates a GPX 1.1 compliant track with metadata.
  /// Handles loop closure by adding closing track point if necessary.
  Future<void> exportGpxRoute(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att exportera')));
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;

    try {
      final builder = xml.XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      builder.element(
        'gpx',
        nest: () {
          builder.attribute('version', '1.1');
          builder.attribute('creator', 'Gravel First');
          builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');

          builder.element(
            'metadata',
            nest: () {
              builder.element(
                'name',
                nest: () {
                  builder.text('Gravel route');
                },
              );
              builder.element(
                'time',
                nest: () {
                  builder.text(DateTime.now().toUtc().toIso8601String());
                },
              );
            },
          );

          builder.element(
            'trk',
            nest: () {
              builder.element(
                'name',
                nest: () {
                  builder.text('Gravel route');
                },
              );
              builder.element(
                'trkseg',
                nest: () {
                  for (final p in routePoints) {
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': p.latitude.toStringAsFixed(7),
                        'lon': p.longitude.toStringAsFixed(7),
                      },
                    );
                  }
                  if (ref.read(loopClosedProvider) && routePoints.length >= 3) {
                    final f = routePoints.first;
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': f.latitude.toStringAsFixed(7),
                        'lon': f.longitude.toStringAsFixed(7),
                      },
                    );
                  }
                },
              );
            },
          );
        },
      );

      final doc = builder.buildDocument();
      final gpxString = doc.toXmlString(pretty: true, indent: '  ');
      final bytes = Uint8List.fromList(utf8.encode(gpxString));

      await FileSaver.instance.saveFile(
        name: 'gravel_route_${DateTime.now().millisecondsSinceEpoch}.gpx',
        bytes: bytes,
        ext: 'gpx',
        mimeType: MimeType.other,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Rutt exporterad som GPX',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPX export misslyckades: $e')));
    } finally {
      if (mounted) {
        ref.read(isExportingProvider.notifier).state = false;
      }
    }
  }

  /// Import route from GPX file
  ///
  /// Uses background isolate for processing large GPX files with automatic
  /// point decimation for performance optimization.
  Future<void> importGpxRoute(
    Function(List<LatLng> points, bool loopClosed) onRouteImported,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
        withData: true,
      );

      if (result?.files.single.bytes == null) return;
      final bytes = result!.files.single.bytes!;

      ref.read(isImportingProvider.notifier).state = true;

      // Use background isolate for large file processing
      final parsedData = await compute(parseGpxPoints, bytes);
      final pts = parsedData['points'] as List<LatLng>;
      final originalCount = parsedData['originalCount'] as int;

      if (!mounted) return;

      if (pts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inga spårpunkter hittades i GPX-filen'),
          ),
        );
        return;
      }

      // GPX doesn't encode loop state; infer if first==last
      final isLoopClosed = pts.length >= 3 && pts.first == pts.last;
      if (isLoopClosed && pts.isNotEmpty && pts.first == pts.last) {
        pts.removeLast(); // Remove duplicated closing point
      }

      onRouteImported(pts, isLoopClosed);

      final decimationInfo = originalCount > pts.length
          ? ' (decimated from $originalCount points)'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX importerad: ${pts.length} punkter$decimationInfo'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPX import misslyckades: $e')));
    } finally {
      if (mounted) {
        ref.read(isImportingProvider.notifier).state = false;
      }
    }
  }
}
