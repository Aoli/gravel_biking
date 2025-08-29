import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart' as xml;

/// Service for handling file import/export functionality
class FileService {
  /// Export route as GeoJSON file with iOS compatibility
  Future<void> exportGeoJsonRoute({
    required BuildContext context,
    required List<LatLng> routePoints,
    required bool loopClosed,
  }) async {
    if (routePoints.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att exportera')));
      return;
    }

    final coords = [
      for (final p in routePoints) [p.longitude, p.latitude],
      if (loopClosed && routePoints.length >= 3)
        [routePoints.first.longitude, routePoints.first.latitude],
    ];

    final feature = {
      'type': 'Feature',
      'properties': {
        'name': 'Gravel route',
        'loopClosed': loopClosed,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'geometry': {'type': 'LineString', 'coordinates': coords},
    };

    final featureCollection = {
      'type': 'FeatureCollection',
      'features': [feature],
    };

    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert(featureCollection);
    final bytes = Uint8List.fromList(utf8.encode(content));

    try {
      // Enhanced web compatibility - especially for Android WebView/browsers
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'gravel_route_${DateTime.now().millisecondsSinceEpoch}.geojson',
          bytes: bytes,
          fileExtension: 'geojson',
          mimeType: MimeType.custom,
          customMimeType: 'application/geo+json',
        );
      } else {
        // For native iOS/Android platforms - use FileSaver directly for better compatibility
        // On Android, this will use the system's file picker/storage access framework
        await FileSaver.instance.saveFile(
          name: 'gravel_route.geojson',
          bytes: bytes,
          fileExtension: 'geojson',
          mimeType: MimeType.custom,
          customMimeType: 'application/geo+json',
        );
      }

      if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export misslyckades: $e')));
    }
  }

  /// Import route from GeoJSON file
  Future<({List<LatLng> points, bool loopClosed})?> importGeoJsonRoute({
    required BuildContext context,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['geojson', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final data = file.bytes ?? Uint8List(0);

      if (data.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selected file is empty')));
        return null;
      }

      final text = utf8.decode(data);
      final decoded = json.decode(text);
      final coordinates = _extractFirstLineString(decoded);

      if (coordinates == null || coordinates.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No LineString found in GeoJSON')),
        );
        return null;
      }

      final points = [
        for (final c in coordinates)
          if (c is List && c.length >= 2)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];

      // Try to read loopClosed from properties
      bool loopClosed = false;
      try {
        if (decoded is Map && decoded['type'] == 'FeatureCollection') {
          final features = decoded['features'];
          if (features is List &&
              features.isNotEmpty &&
              features.first is Map) {
            final properties = (features.first as Map)['properties'];
            if (properties is Map && properties['loopClosed'] is bool) {
              loopClosed = properties['loopClosed'] as bool;
            }
          }
        } else if (decoded is Map && decoded['type'] == 'Feature') {
          final properties = decoded['properties'];
          if (properties is Map && properties['loopClosed'] is bool) {
            loopClosed = properties['loopClosed'] as bool;
          }
        }
      } catch (_) {}

      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importerade ${points.length} punkter',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      return (points: points, loopClosed: loopClosed && points.length >= 3);
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      return null;
    }
  }

  /// Export route as GPX file with iOS compatibility
  Future<void> exportGpxRoute({
    required BuildContext context,
    required List<LatLng> routePoints,
    required bool loopClosed,
  }) async {
    if (routePoints.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att exportera')));
      return;
    }

    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', 'Gravel First');
        builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');

        builder.element(
          'trk',
          nest: () {
            builder.element('name', nest: 'Gravel route');
            builder.element(
              'trkseg',
              nest: () {
                for (final point in routePoints) {
                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': point.latitude.toStringAsFixed(7),
                      'lon': point.longitude.toStringAsFixed(7),
                    },
                  );
                }
                // Add closing point for loop
                if (loopClosed && routePoints.length >= 3) {
                  final firstPoint = routePoints.first;
                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': firstPoint.latitude.toStringAsFixed(7),
                      'lon': firstPoint.longitude.toStringAsFixed(7),
                    },
                  );
                }
              },
            );
          },
        );
      },
    );

    final gpxString = builder.buildDocument().toXmlString(pretty: true);
    final bytes = Uint8List.fromList(utf8.encode(gpxString));

    try {
      // Enhanced web compatibility - especially for Android WebView/browsers
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'gravel_route_${DateTime.now().millisecondsSinceEpoch}.gpx',
          bytes: bytes,
          fileExtension: 'gpx',
          mimeType: MimeType.custom,
          customMimeType: 'application/gpx+xml',
        );
      } else {
        // For native iOS/Android platforms - use FileSaver directly for better compatibility
        // On Android, this will use the system's file picker/storage access framework
        await FileSaver.instance.saveFile(
          name: 'gravel_route.gpx',
          bytes: bytes,
          fileExtension: 'gpx',
          mimeType: MimeType.custom,
          customMimeType: 'application/gpx+xml',
        );
      }

      if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export misslyckades: $e')));
    }
  }

  /// Import route from GPX file
  Future<List<LatLng>?> importGpxRoute({required BuildContext context}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['gpx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final data = file.bytes ?? Uint8List(0);

      if (data.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selected file is empty')));
        return null;
      }

      final text = utf8.decode(data);
      final document = xml.XmlDocument.parse(text);
      final points = <LatLng>[];

      // Extract track points
      for (final trkpt in document.findAllElements('trkpt')) {
        final latStr = trkpt.getAttribute('lat');
        final lonStr = trkpt.getAttribute('lon');

        if (latStr != null && lonStr != null) {
          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);
          if (lat != null && lon != null) {
            points.add(LatLng(lat, lon));
          }
        }
      }

      if (points.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No track points found in GPX')),
        );
        return null;
      }

      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importerade ${points.length} punkter från GPX',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      return points;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPX import failed: $e')));
      return null;
    }
  }

  /// Extract first LineString coordinates from GeoJSON
  List<dynamic>? _extractFirstLineString(dynamic node) {
    if (node is Map) {
      final type = node['type'];
      if (type == 'FeatureCollection' && node['features'] is List) {
        for (final feature in (node['features'] as List)) {
          final result = _extractFirstLineString(feature);
          if (result != null) return result;
        }
      } else if (type == 'Feature' && node['geometry'] is Map) {
        return _extractFirstLineString(node['geometry']);
      } else if (type == 'LineString' && node['coordinates'] is List) {
        return node['coordinates'] as List;
      } else if (type == 'MultiLineString' && node['coordinates'] is List) {
        final lines = node['coordinates'] as List;
        if (lines.isNotEmpty && lines.first is List) {
          return lines.first as List; // Take the first line
        }
      }
    }
    return null;
  }
}
