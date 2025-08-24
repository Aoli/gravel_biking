import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/saved_route.dart';
import '../services/file_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../utils/coordinate_utils.dart';
import '../widgets/distance_panel.dart';
import '../widgets/point_marker.dart';

/// Main map screen for the Gravel Biking app
class GravelStreetsMap extends StatefulWidget {
  const GravelStreetsMap({super.key});

  @override
  State<GravelStreetsMap> createState() => _GravelStreetsMapState();
}

class _GravelStreetsMapState extends State<GravelStreetsMap> {
  // Services
  final RouteService _routeService = RouteService();
  final LocationService _locationService = LocationService();
  final FileService _fileService = FileService();

  // Map data
  List<Polyline> gravelPolylines = [];
  final bool _showGravelOverlay = true;
  bool isLoading = true;
  LatLng? _myPosition;
  Timer? _moveDebounce;
  LatLngBounds? _lastFetchedBounds;
  LatLngBounds? _lastEventBounds;

  // Map control
  final MapController _mapController = MapController();
  double? _lastZoom;

  // App info
  final String _buildNumber = const String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );
  String _appVersion = '';

  // Measurement
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  final bool _measureEnabled = false;
  bool _loopClosed = false;
  int? _editingIndex;

  // Saved routes
  final List<SavedRoute> _savedRoutes = [];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSavedRoutes();
    // Initial fetch for Stockholm area
    _fetchGravelForBounds(
      LatLngBounds(const LatLng(59.3, 18.0), const LatLng(59.4, 18.1)),
    );
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadSavedRoutes() async {
    final routes = await _routeService.loadSavedRoutes();
    setState(() {
      _savedRoutes.clear();
      _savedRoutes.addAll(routes);
    });
  }

  Future<void> _saveSavedRoutes() async {
    await _routeService.saveSavedRoutes(_savedRoutes);
  }

  Future<void> _saveCurrentRoute(String name) async {
    try {
      final route = await _routeService.saveCurrentRoute(
        name: name,
        routePoints: _routePoints,
        loopClosed: _loopClosed,
      );

      final updatedRoutes = _routeService.addRouteToSaved(_savedRoutes, route);

      setState(() {
        _savedRoutes.clear();
        _savedRoutes.addAll(updatedRoutes);
      });

      await _saveSavedRoutes();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rutt "$name" sparad')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _loadSavedRoute(SavedRoute route) async {
    setState(() {
      _routePoints.clear();
      _routePoints.addAll(route.points);
      _segmentMeters.clear();
      _editingIndex = null;
      _loopClosed = route.loopClosed;

      // Recalculate segment distances
      _segmentMeters.addAll(
        _routeService.calculateSegmentDistances(
          routePoints: _routePoints,
          loopClosed: _loopClosed,
        ),
      );
    });

    // Center map on the loaded route
    if (_routePoints.isNotEmpty) {
      _routeService.centerMapOnRoute(
        mapController: _mapController,
        routePoints: _routePoints,
      );
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close drawer
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rutt "${route.name}" laddad')));
    }
  }

  Future<void> _deleteSavedRoute(int index) async {
    final routeName = _savedRoutes[index].name;
    final updatedRoutes = _routeService.removeRouteAt(_savedRoutes, index);

    setState(() {
      _savedRoutes.clear();
      _savedRoutes.addAll(updatedRoutes);
    });

    await _saveSavedRoutes();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rutt "$routeName" borttagen')));
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event.camera.zoom != _lastZoom) {
      _lastZoom = event.camera.zoom;
    }
    _queueViewportFetch();
  }

  void _queueViewportFetch() {
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 200), () {
      final bounds = _mapController.camera.visibleBounds;
      if (_lastEventBounds != null &&
          _lastEventBounds!.contains(bounds.northWest) &&
          _lastEventBounds!.contains(bounds.southEast)) {
        return;
      }
      _lastEventBounds = bounds;

      if (_showGravelOverlay) {
        _fetchGravelForBounds(bounds);
      }
    });
  }

  Future<void> _fetchGravelForBounds(LatLngBounds bounds) async {
    if (_lastFetchedBounds != null &&
        _lastFetchedBounds!.contains(bounds.northWest) &&
        _lastFetchedBounds!.contains(bounds.southEast)) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    _lastFetchedBounds = bounds;

    try {
      final overpassQuery =
          '''
[out:json][timeout:25];
(
  way["highway"~"^(track|path|footway)\$"]["surface"~"(gravel|compacted|fine_gravel|ground|dirt|earth|grass|unpaved|sand)"][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
  way["highway"~"^(cycleway|bridleway)\$"][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
  way["highway"="unclassified"]["surface"~"(gravel|compacted|fine_gravel|ground|dirt|earth|grass|unpaved|sand)"][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
  way["route"="mtb"][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
);
out geom;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: overpassQuery,
      );

      if (response.statusCode == 200) {
        final polylineCoords = CoordinateUtils.extractPolylineCoords(
          response.body,
        );
        final newPolylines = polylineCoords.map((coords) {
          return Polyline(
            points: coords.map((c) => LatLng(c[0], c[1])).toList(),
            strokeWidth: 3,
            color: Colors.brown.withValues(alpha: 0.8),
          );
        }).toList();

        setState(() {
          gravelPolylines = newPolylines;
          isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching gravel data: $e');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  void _undoLastPoint() {
    if (_routePoints.isNotEmpty) {
      setState(() {
        _routePoints.removeLast();
        _editingIndex = null;
        _loopClosed = false;
        _recomputeSegments();
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints.clear();
      _segmentMeters.clear();
      _editingIndex = null;
      _loopClosed = false;
    });
  }

  void _toggleLoop() {
    setState(() {
      _loopClosed = !_loopClosed;
      _recomputeSegments();
    });
  }

  void _recomputeSegments() {
    _segmentMeters.clear();
    _segmentMeters.addAll(
      _routeService.calculateSegmentDistances(
        routePoints: _routePoints,
        loopClosed: _loopClosed,
      ),
    );
  }

  void _deletePoint(int index) {
    setState(() {
      _routePoints.removeAt(index);
      _editingIndex = null;
      _loopClosed = false;
      _recomputeSegments();
    });
  }

  Future<void> _locateMe() async {
    final position = await _locationService.locateMe(
      context: context,
      mapController: _mapController,
      lastZoom: _lastZoom,
    );

    if (position != null) {
      setState(() {
        _myPosition = position;
      });
    }
  }

  Future<void> _showSaveRouteDialog() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spara rutt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ange ett namn för rutten (max ${RouteService.maxSavedRoutes} sparade rutter):',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ruttnamn',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _saveCurrentRoute(result);
    }
  }

  Future<void> _showSavedRoutesHelpDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Om sparade rutter'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Observera att sparade rutter endast lagras på enheten. '
                'För att säkerhetskopiiera eller flytta rutter till andra enheter, '
                'använd Import/Export funktionerna nedan.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                'Export till GeoJSON eller GPX:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Kompatibelt med Strava, Garmin Connect, Komoot'),
              Text('• Kan importeras i andra karttjänster'),
              Text('• Säker långtidslagring'),
              SizedBox(height: 8),
              Text(
                'Maxgräns: 5 sparade rutter per enhet',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stäng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ... (will continue with the build method in the next section)

    return Scaffold(
      // Build method implementation continues...
      body: Container(), // Placeholder for now
    );
  }
}
