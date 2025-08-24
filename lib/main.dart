import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xml/xml.dart' as xml;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data model for saved routes
class SavedRoute {
  final String name;
  final List<LatLng> points;
  final DateTime savedAt;

  SavedRoute({required this.name, required this.points, required this.savedAt});

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'points': points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'savedAt': savedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      name: json['name'],
      points: (json['points'] as List)
          .map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
      savedAt: DateTime.parse(json['savedAt']),
    );
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel First',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontWeight: FontWeight.w400),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black26,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            elevation: 1,
            shadowColor: Colors.black26,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontWeight: FontWeight.w400),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black54,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            elevation: 1,
            shadowColor: Colors.black54,
          ),
        ),
      ),
      home: const GravelStreetsMap(),
    );
  }
}

// Parse Overpass JSON off the UI thread
List<List<List<double>>> _extractPolylineCoords(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  final elements = (data['elements'] as List?) ?? const [];
  final result = <List<List<double>>>[];
  for (final e in elements) {
    if (e is Map && e['type'] == 'way' && e['geometry'] is List) {
      final pts = <List<double>>[];
      for (final n in (e['geometry'] as List)) {
        if (n is Map && n['lat'] is num && n['lon'] is num) {
          pts.add([(n['lat'] as num).toDouble(), (n['lon'] as num).toDouble()]);
        }
      }
      if (pts.length >= 2) result.add(pts);
    }
  }
  return result;
}

class GravelStreetsMap extends StatefulWidget {
  const GravelStreetsMap({super.key});
  @override
  State<GravelStreetsMap> createState() => _GravelStreetsMapState();
}

class _GravelStreetsMapState extends State<GravelStreetsMap> {
  // Data
  List<Polyline> gravelPolylines = [];
  bool _showGravelOverlay = true;
  final bool _showTrvNvdbOverlay =
      false; // Disabled by default, prepared for future
  bool isLoading = true;
  LatLng? _myPosition;
  Timer? _moveDebounce;
  LatLngBounds? _lastFetchedBounds;
  LatLngBounds? _lastEventBounds;
  // Map control
  final MapController _mapController = MapController();
  double? _lastZoom;
  // CI/CD build number (provided via --dart-define=BUILD_NUMBER=123), empty locally
  final String _buildNumber = const String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );
  // App version from pubspec.yaml
  String _appVersion = '';

  // Measurement
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  bool _measureEnabled = false;
  bool _loopClosed = false;
  int? _editingIndex;

  // Saved routes
  final List<SavedRoute> _savedRoutes = [];
  static const int _maxSavedRoutes = 5;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSavedRoutes();
    // Initial fetch for a sensible area (Stockholm bbox)
    _fetchGravelForBounds(
      LatLngBounds(const LatLng(59.3, 18.0), const LatLng(59.4, 18.1)),
    );
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  // Saved Routes Management
  Future<void> _loadSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList('saved_routes') ?? [];

    setState(() {
      _savedRoutes.clear();
      for (final routeJson in routesJson) {
        try {
          final route = SavedRoute.fromJson(json.decode(routeJson));
          _savedRoutes.add(route);
        } catch (e) {
          debugPrint('Error loading saved route: $e');
        }
      }
    });
  }

  Future<void> _saveSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = _savedRoutes
        .map((route) => json.encode(route.toJson()))
        .toList();
    await prefs.setStringList('saved_routes', routesJson);
  }

  Future<void> _saveCurrentRoute(String name) async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    // Remove oldest route if we're at the limit
    if (_savedRoutes.length >= _maxSavedRoutes) {
      _savedRoutes.removeAt(0);
    }

    final newRoute = SavedRoute(
      name: name,
      points: List.from(_routePoints),
      savedAt: DateTime.now(),
    );

    setState(() {
      _savedRoutes.add(newRoute);
    });

    await _saveSavedRoutes();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rutt "$name" sparad')));
    }
  }

  Future<void> _loadSavedRoute(SavedRoute route) async {
    setState(() {
      _routePoints.clear();
      _routePoints.addAll(route.points);
      _segmentMeters.clear();
      _editingIndex = null;
      _loopClosed = false;

      // Recalculate segment distances
      for (int i = 1; i < _routePoints.length; i++) {
        _segmentMeters.add(
          _distance.as(LengthUnit.Meter, _routePoints[i - 1], _routePoints[i]),
        );
      }
    });

    // Center map on the loaded route
    if (_routePoints.isNotEmpty) {
      _centerMapOnRoute();
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close drawer
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rutt "${route.name}" laddad')));
    }
  }

  void _centerMapOnRoute() {
    if (_routePoints.isEmpty) return;

    if (_routePoints.length == 1) {
      _mapController.move(_routePoints.first, 15);
    } else {
      // Calculate bounds of all route points
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;

      for (final point in _routePoints) {
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

      _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
    }
  }

  Future<void> _deleteSavedRoute(int index) async {
    final routeName = _savedRoutes[index].name;
    setState(() {
      _savedRoutes.removeAt(index);
    });
    await _saveSavedRoutes();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rutt "$routeName" borttagen')));
    }
  }

  Future<void> _showSaveRouteDialog() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    final TextEditingController nameController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Spara rutt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_savedRoutes.length >= _maxSavedRoutes)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Maxantal rutter nått (5). Den äldsta rutten kommer att tas bort.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Ruttnamn',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                autofocus: true,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop();
                    _saveCurrentRoute(value.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop();
                  _saveCurrentRoute(name);
                }
              },
              child: const Text('Spara'),
            ),
          ],
        );
      },
    );
  }

  void _onMapEvent(MapEvent event) {
    // Debounce on any map movement/zoom/rotate event
    _lastEventBounds = event.camera.visibleBounds;
    _lastZoom = event.camera.zoom;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(
      const Duration(milliseconds: 500),
      _queueViewportFetch,
    );
  }

  void _queueViewportFetch() {
    final bounds = _lastEventBounds;
    if (bounds == null) return;
    if (_lastFetchedBounds != null &&
        _boundsAlmostEqual(_lastFetchedBounds!, bounds)) {
      return;
    }
    _fetchGravelForBounds(bounds);
  }

  bool _boundsAlmostEqual(
    LatLngBounds a,
    LatLngBounds b, {
    double tol = 0.0005,
  }) {
    double d(double x, double y) => (x - y).abs();
    return d(a.southWest.latitude, b.southWest.latitude) < tol &&
        d(a.southWest.longitude, b.southWest.longitude) < tol &&
        d(a.northEast.latitude, b.northEast.latitude) < tol &&
        d(a.northEast.longitude, b.northEast.longitude) < tol;
  }

  Future<void> _fetchGravelForBounds(LatLngBounds bounds) async {
    _lastFetchedBounds = bounds;
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
    try {
      final res = await http.post(Uri.parse(url), body: {'data': query});
      if (res.statusCode == 200) {
        final lines = await compute(_extractPolylineCoords, res.body);
        final polys = <Polyline>[
          for (final pts in lines)
            Polyline(
              points: [for (final p in pts) LatLng(p[0], p[1])],
              color: Colors.brown,
              strokeWidth: 4,
            ),
        ];
        if (!mounted) return;
        setState(() {
          gravelPolylines = polys;
          isLoading = false;
        });
      } else {
        debugPrint('Failed to load gravel streets: ${res.statusCode}');
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gravel First',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 1,
        shadowColor: Colors.black26,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.secondaryContainer,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: IconButton(
              tooltip: 'Hitta mig',
              icon: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                size: 22,
              ),
              onPressed: _locateMe,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _measureEnabled
                  ? Colors.green.shade600
                  : Colors.red.shade600,
              border: Border.all(
                color: _measureEnabled
                    ? Colors.green.shade800
                    : Colors.red.shade800,
                width: 2,
              ),
            ),
            child: IconButton(
              tooltip: _measureEnabled
                  ? 'Stäng av mätläge'
                  : 'Aktivera mätläge',
              icon: const Icon(Icons.straighten, color: Colors.white, size: 22),
              onPressed: () =>
                  setState(() => _measureEnabled = !_measureEnabled),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Meny',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Import / Export',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      leading: Icon(
                        Icons.folder_open,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    ExpansionTile(
                      leading: Icon(
                        Icons.map,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        'GeoJSON',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      initiallyExpanded: false,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.file_open,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          title: Text(
                            'Importera GeoJSON',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _importGeoJsonRoute();
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.save_alt,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          title: Text(
                            'Exportera GeoJSON',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _exportGeoJsonRoute();
                          },
                        ),
                      ],
                    ),
                    ExpansionTile(
                      leading: Icon(
                        Icons.route,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        'GPX',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      initiallyExpanded: false,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.file_open,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          title: Text(
                            'Importera GPX',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _importGpxRoute();
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.file_download,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          title: Text(
                            'Exportera GPX',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _exportGpxRoute();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.layers,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        'Grus-lager',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        'Visa OpenStreetMap/Overpass grusvägar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _showGravelOverlay,
                      onChanged: (v) => setState(() => _showGravelOverlay = v),
                    ),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.alt_route,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        'TRV NVDB grus-lager',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        'Visa Trafikverket NVDB grusvägar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _showTrvNvdbOverlay,
                      onChanged: null, // Disabled for now
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    // Saved Routes Section
                    ExpansionTile(
                      leading: Icon(
                        Icons.bookmark,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        'Sparade rutter',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${_savedRoutes.length}/5 rutter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      initiallyExpanded: false,
                      children: [
                        // Save current route button
                        ListTile(
                          leading: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Spara aktuell rutt',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          enabled: _routePoints.isNotEmpty,
                          onTap: () {
                            Navigator.of(context).pop();
                            _showSaveRouteDialog();
                          },
                        ),
                        if (_savedRoutes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Inga sparade rutter ännu',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...List.generate(_savedRoutes.length, (index) {
                            final route = _savedRoutes[index];
                            return ListTile(
                              leading: Icon(
                                Icons.route,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              title: Text(
                                route.name,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                '${route.points.length} punkter • ${route.savedAt.day}/${route.savedAt.month}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20,
                                ),
                                onPressed: () => _deleteSavedRoute(index),
                              ),
                              onTap: () => _loadSavedRoute(route),
                            );
                          }),
                      ],
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Stäng',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '© Gravel First 2025',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final parts = <String>[];
                        if (_appVersion.isNotEmpty) parts.add('v$_appVersion');
                        if (_buildNumber.isNotEmpty)
                          parts.add('#$_buildNumber');
                        final label = parts.join(' ');
                        if (label.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w300,
                                  fontSize: 11,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(59.3293, 18.0686),
              initialZoom: 12,
              onMapEvent: _onMapEvent,
              onTap: (tap, latLng) {
                if (!_measureEnabled) return;
                setState(() {
                  if (_editingIndex != null) {
                    // Move selected point to this location
                    _routePoints[_editingIndex!] = latLng;
                    _editingIndex = null;
                    _recomputeSegments();
                  } else {
                    if (_loopClosed) _loopClosed = false; // re-open when adding
                    _routePoints.add(latLng);
                    _recomputeSegments();
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.gravel_biking',
              ),
              if (_showGravelOverlay) PolylineLayer(polylines: gravelPolylines),
              PolylineLayer(
                polylines: [
                  if (_routePoints.length >= 2)
                    Polyline(
                      points: _loopClosed && _routePoints.length >= 3
                          ? [..._routePoints, _routePoints.first]
                          : _routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3,
                    ),
                ],
              ),
              if (_myPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPosition!,
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.25),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (int i = 0; i < _routePoints.length; i++)
                    Marker(
                      point: _routePoints[i],
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => setState(() => _editingIndex = i),
                        onLongPress: () => _deletePoint(i),
                        child: _PointMarker(
                          index: i,
                          isEditing: _editingIndex == i,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (_buildNumber.isNotEmpty)
            Positioned(
              bottom: 10,
              left: 12,
              child: Text(
                '#$_buildNumber',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DistancePanel(
                    segmentMeters: _segmentMeters,
                    onUndo: _undoLastPoint,
                    onSave: _showSaveRouteDialog,
                    onClear: _clearRoute,
                    theme: Theme.of(context),
                    measureEnabled: _measureEnabled,
                    loopClosed: _loopClosed,
                    canToggleLoop: _routePoints.length >= 3,
                    onToggleLoop: _toggleLoop,
                    editingIndex: _editingIndex,
                    onCancelEdit: () => setState(() => _editingIndex = null),
                  ),
                ],
              ),
            ),
          ),
          // Subtle build/version watermark (e.g., v1.2.3 #27)
          Builder(
            builder: (context) {
              final parts = <String>[];
              if (_appVersion.isNotEmpty) parts.add('v$_appVersion');
              if (_buildNumber.isNotEmpty) parts.add('#$_buildNumber');
              final label = parts.join(' ');
              if (label.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: 12,
                left: 12,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: 'Återställ kartposition',
                    icon: const Icon(Icons.center_focus_strong, size: 20),
                    onPressed: () {
                      _mapController.move(const LatLng(59.3293, 18.0686), 12);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  void _undoLastPoint() {
    if (_routePoints.isEmpty) return;
    setState(() {
      _routePoints.removeLast();
      if (_routePoints.length < 3) _loopClosed = false;
      _recomputeSegments();
    });
  }

  void _clearRoute() {
    if (_routePoints.isEmpty && _segmentMeters.isEmpty) return;
    setState(() {
      _routePoints.clear();
      _segmentMeters.clear();
      _loopClosed = false;
      _editingIndex = null;
    });
  }

  void _toggleLoop() {
    if (_routePoints.length < 3) return;
    setState(() {
      _loopClosed = !_loopClosed;
      _recomputeSegments();
    });
  }

  void _recomputeSegments() {
    _segmentMeters
      ..clear()
      ..addAll(_computeSegments(_routePoints, _loopClosed));
  }

  List<double> _computeSegments(List<LatLng> pts, bool closed) {
    if (pts.length < 2) return const [];
    final segs = <double>[];
    for (int i = 1; i < pts.length; i++) {
      segs.add(_distance.as(LengthUnit.Meter, pts[i - 1], pts[i]));
    }
    if (closed && pts.length >= 3) {
      segs.add(_distance.as(LengthUnit.Meter, pts.last, pts.first));
    }
    return segs;
  }

  void _deletePoint(int index) {
    if (index < 0 || index >= _routePoints.length) return;
    setState(() {
      _routePoints.removeAt(index);
      if (_routePoints.length < 3) _loopClosed = false;
      if (_editingIndex != null) {
        if (_routePoints.isEmpty) {
          _editingIndex = null;
        } else if (index == _editingIndex) {
          _editingIndex = null;
        } else if (index < _editingIndex!) {
          _editingIndex = _editingIndex! - 1;
        }
      }
      _recomputeSegments();
    });
  }

  Future<void> _locateMe() async {
    try {
      // Check and request permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Positionstjänster är avaktiverade',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Positionstillstånd nekat',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _myPosition = latLng;
      });
      // Center the map on the located position using the last known zoom (fallback to 14)
      final z = _lastZoom ?? 14.0;
      _mapController.move(latLng, z);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kunde inte hämta position: $e',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _exportGeoJsonRoute() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att exportera')));
      return;
    }
    final coords = [
      for (final p in _routePoints) [p.longitude, p.latitude],
      if (_loopClosed && _routePoints.length >= 3)
        [_routePoints.first.longitude, _routePoints.first.latitude],
    ];
    final feature = {
      'type': 'Feature',
      'properties': {
        'name': 'Gravel route',
        'loopClosed': _loopClosed,
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
    try {
      await FileSaver.instance.saveFile(
        name: 'gravel_route.geojson',
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
    }
  }

  Future<void> _importGeoJsonRoute() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['geojson', 'json'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      final data = file.bytes ?? Uint8List(0);
      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selected file is empty')));
        return;
      }
      final text = utf8.decode(data);
      final decoded = json.decode(text);
      final extract = _extractFirstLineString(decoded);
      if (extract == null || extract.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No LineString found in GeoJSON')),
        );
        return;
      }
      final imported = [
        for (final c in extract)
          if (c is List && c.length >= 2)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      bool loopClosed = false;
      // Try to read loopClosed from common places
      try {
        if (decoded is Map && decoded['type'] == 'FeatureCollection') {
          final feats = decoded['features'];
          if (feats is List && feats.isNotEmpty && feats.first is Map) {
            final props = (feats.first as Map)['properties'];
            if (props is Map && props['loopClosed'] is bool) {
              loopClosed = props['loopClosed'] as bool;
            }
          }
        } else if (decoded is Map && decoded['type'] == 'Feature') {
          final props = decoded['properties'];
          if (props is Map && props['loopClosed'] is bool) {
            loopClosed = props['loopClosed'] as bool;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _routePoints
          ..clear()
          ..addAll(imported);
        _editingIndex = null;
        _loopClosed = loopClosed && _routePoints.length >= 3;
        _recomputeSegments();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importerade ${_routePoints.length} punkter',
            style: const TextStyle(fontWeight: FontWeight.w500),
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
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  // Returns coordinates array of a LineString ([ [lon,lat], ... ]) or null
  List<dynamic>? _extractFirstLineString(dynamic node) {
    if (node is Map) {
      final type = node['type'];
      if (type == 'FeatureCollection' && node['features'] is List) {
        for (final f in (node['features'] as List)) {
          final res = _extractFirstLineString(f);
          if (res != null) return res;
        }
      } else if (type == 'Feature' && node['geometry'] is Map) {
        return _extractFirstLineString(node['geometry']);
      } else if (type == 'LineString' && node['coordinates'] is List) {
        return node['coordinates'] as List;
      } else if (type == 'MultiLineString' && node['coordinates'] is List) {
        final lines = node['coordinates'] as List;
        if (lines.isNotEmpty && lines.first is List) {
          return lines.first as List; // take the first line by default
        }
      }
    }
    return null;
  }

  Future<void> _exportGpxRoute() async {
    if (_routePoints.isEmpty) {
      if (!mounted) return;
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
                for (final p in _routePoints) {
                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': p.latitude.toStringAsFixed(7),
                      'lon': p.longitude.toStringAsFixed(7),
                    },
                  );
                }
                if (_loopClosed && _routePoints.length >= 3) {
                  final f = _routePoints.first;
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
    final gpxString = builder.buildDocument().toXmlString(pretty: true);
    try {
      await FileSaver.instance.saveFile(
        name: 'gravel_route.gpx',
        bytes: Uint8List.fromList(utf8.encode(gpxString)),
        ext: 'gpx',
        mimeType: MimeType.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rutt exporterad som GPX')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export misslyckades: $e')));
    }
  }

  Future<void> _importGpxRoute() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['gpx', 'xml'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      final data = file.bytes ?? Uint8List(0);
      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selected file is empty')));
        return;
      }
      final text = utf8.decode(data);
      final doc = xml.XmlDocument.parse(text);
      final trkpts = doc.findAllElements('trkpt');
      final pts = <LatLng>[];
      for (final p in trkpts) {
        final latStr = p.getAttribute('lat');
        final lonStr = p.getAttribute('lon');
        if (latStr != null && lonStr != null) {
          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);
          if (lat != null && lon != null) pts.add(LatLng(lat, lon));
        }
      }
      if (pts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inga spårpunkter hittades i GPX')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _routePoints
          ..clear()
          ..addAll(pts);
        _editingIndex = null;
        // GPX doesn’t encode loop state; infer if first==last
        _loopClosed = pts.length >= 3 && pts.first == pts.last;
        if (_loopClosed && pts.isNotEmpty && pts.first == pts.last) {
          // remove duplicated closing point for internal representation
          _routePoints.removeLast();
        }
        _recomputeSegments();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importerade ${_routePoints.length} punkter från GPX'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _PointMarker extends StatelessWidget {
  final int index;
  final bool isEditing;
  const _PointMarker({required this.index, this.isEditing = false});
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isEditing ? tertiaryColor : primaryColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

class _DistancePanel extends StatelessWidget {
  final List<double> segmentMeters;
  final VoidCallback onUndo;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final ThemeData theme;
  final bool measureEnabled;
  final bool loopClosed;
  final bool canToggleLoop;
  final VoidCallback onToggleLoop;
  final int? editingIndex;
  final VoidCallback onCancelEdit;

  const _DistancePanel({
    required this.segmentMeters,
    required this.onUndo,
    required this.onSave,
    required this.onClear,
    required this.theme,
    required this.measureEnabled,
    required this.loopClosed,
    required this.canToggleLoop,
    required this.onToggleLoop,
    required this.editingIndex,
    required this.onCancelEdit,
  });

  double get _totalMeters => segmentMeters.fold(0.0, (a, b) => a + b);

  String _fmt(double meters) {
    if (meters < 950) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black26,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.straighten, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mätning',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ångra senaste punkt',
                          icon: const Icon(Icons.undo, size: 18),
                          color: onSurface,
                          onPressed: onUndo,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Spara rutt',
                          icon: const Icon(Icons.bookmark_add, size: 18),
                          color: primaryColor,
                          onPressed: onSave,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Rensa rutt',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: theme.colorScheme.error,
                          onPressed: onClear,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canToggleLoop) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: onSurface,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      elevation: 1,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: onToggleLoop,
                    icon: Icon(
                      loopClosed ? Icons.link_off : Icons.link,
                      size: 16,
                      color: primaryColor,
                    ),
                    label: Text(
                      loopClosed ? 'Öppna slinga' : 'Stäng slinga',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (editingIndex != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 16,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Redigerar punkt #${editingIndex! + 1} — tryck på kartan för att flytta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Avbryt redigering',
                        icon: const Icon(Icons.close, size: 16),
                        color: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onCancelEdit,
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total: ${_fmt(_totalMeters)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (segmentMeters.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tryck på kartan för att lägga till punkter i redigeringsläge (grön redigeringsknapp)',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            int i = 0;
                            i < segmentMeters.length - (loopClosed ? 1 : 0);
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Segment ${i + 1}: ${_fmt(segmentMeters[i])}',
                                style: TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          if (loopClosed && segmentMeters.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Loop segment: ${_fmt(segmentMeters.last)}',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// (Import/Export UI moved into Drawer)
