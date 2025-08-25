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

// Import our refactored components
import 'models/saved_route.dart';
import 'utils/coordinate_utils.dart';
import 'widgets/point_marker.dart';
import 'widgets/distance_panel.dart';
import 'screens/saved_routes_page.dart';
import 'services/route_service.dart';

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
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        iconTheme: IconThemeData(
          // Ensure icons are rendered properly across all platforms
          applyTextScaling: false,
          // Force icon font loading
          size: 24,
          // Web-specific optimizations for Material Icons
          color: kIsWeb ? Colors.black87 : null,
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
        iconTheme: IconThemeData(
          // Ensure icons are rendered properly across all platforms
          applyTextScaling: false,
          // Force icon font loading
          size: 24,
          // Web-specific optimizations for Material Icons
          color: kIsWeb ? Colors.white : null,
        ),
      ),
      home: const GravelStreetsMap(),
    );
  }
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

  // Loading states for file operations
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isSaving = false;

  // Dynamic point sizing based on route point density
  // This system automatically adjusts marker sizes to prevent visual overlap in dense routes
  double _calculateDynamicPointSize() {
    if (_routePoints.length < 2) return 18.0; // Default size for single points

    // Calculate average distance between consecutive points to determine density
    double totalDistance = 0.0;
    int validSegments = 0;

    for (int i = 1; i < _routePoints.length; i++) {
      final segmentDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
      if (segmentDistance > 0) {
        // Avoid division by zero for duplicate points
        totalDistance += segmentDistance;
        validSegments++;
      }
    }

    if (validSegments == 0) return 18.0;

    final averageDistance = totalDistance / validSegments;

    // Adaptive sizing algorithm prevents point overlap:
    // - Very sparse points (>1000m apart): 20px - Large, clearly visible
    // - Sparse points (500-1000m apart): 18px - Standard size
    // - Medium density (200-500m apart): 16px - Slightly smaller
    // - Dense points (100-200m apart): 14px - Smaller for clarity
    // - Very dense (50-100m apart): 12px - Much smaller to prevent overlap
    // - Extremely dense (<50m apart): 10px - Minimal size for very detailed routes
    if (averageDistance > 1000) return 20.0;
    if (averageDistance > 500) return 18.0;
    if (averageDistance > 200) return 16.0;
    if (averageDistance > 100) return 14.0;
    if (averageDistance > 50) return 12.0;
    return 10.0;
  }

  // Saved routes
  final List<SavedRoute> _savedRoutes = [];
  static const int _maxSavedRoutes = 50; // Updated from 5 to 50
  late final RouteService _routeService;

  @override
  void initState() {
    super.initState();
    _routeService = RouteService();
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
    try {
      final routes = await _routeService.loadSavedRoutes();
      setState(() {
        _savedRoutes.clear();
        _savedRoutes.addAll(routes);
      });
    } catch (e) {
      debugPrint('Error loading saved routes: $e');
    }
  }

  Future<void> _saveCurrentRouteInternal(String name) async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    print('Starting save operation for: $name');
    setState(() => _isSaving = true);

    try {
      // Add a small delay to make loading indicator visible
      await Future.delayed(const Duration(milliseconds: 100));

      print('Calling route service save...');
      await _routeService.saveCurrentRoute(
        name: name,
        routePoints: _routePoints,
        loopClosed: _loopClosed,
        description: null, // Can be enhanced later with description input
      );

      print('Save completed, reloading routes...');
      await _loadSavedRoutes(); // Refresh the local list

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rutt "$name" sparad')));
      }
    } catch (e) {
      print('Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fel vid sparande: $e')));
      }
    } finally {
      if (mounted) {
        print('Clearing save loading state');
        setState(() => _isSaving = false);
      }
    }
  }

  /// Load route from SavedRoutesPage - no navigation pops needed
  void _loadRouteFromList(List<LatLng> routePoints) {
    setState(() {
      _routePoints.clear();
      _routePoints.addAll(routePoints);
      _segmentMeters.clear();
      _editingIndex = null;
      _loopClosed = false; // Will be updated by the service if needed

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

  Future<void> _showSaveRouteDialog() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    final TextEditingController nameController = TextEditingController();
    bool isDialogSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Always prevent dismissing during save
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Spara rutt'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_savedRoutes.length >= _maxSavedRoutes)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Maxantal rutter nått (50). Den äldsta rutten kommer att tas bort.',
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
                    enabled: !isDialogSaving,
                    onSubmitted: (value) async {
                      if (value.trim().isNotEmpty && !isDialogSaving) {
                        setDialogState(() => isDialogSaving = true);
                        await _saveCurrentRouteInternal(value.trim());
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                  if (isDialogSaving)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Sparar rutt...'),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Avbryt'),
                ),
                ElevatedButton(
                  onPressed: isDialogSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            setDialogState(() => isDialogSaving = true);
                            await _saveCurrentRouteInternal(name);
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                  child: isDialogSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Spara'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSavedRoutesHelpDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.help,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Om sparade rutter'),
            ],
          ),
          content: const Text(
            'Sparade rutter lagras endast lokalt på din enhet och försvinner om appen avinstalleras eller enhetens data rensas.\n\n'
            'För mer varaktig lagring eller för att flytta rutter till andra tjänster som Strava, Garmin Connect eller andra appar, använd Import/Export funktionerna för att spara som GeoJSON eller GPX-filer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
        final lines = await compute(
          CoordinateUtils.extractPolylineCoords,
          res.body,
        );
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
                          'Gravel First',
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
                        Icons.folder,
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
                          leading: _isImporting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.upload_file,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          title: Text(
                            _isImporting
                                ? 'Importerar GeoJSON...'
                                : 'Importera GeoJSON',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          enabled: !_isImporting && !_isExporting,
                          onTap: () async {
                            // Set loading state first while drawer is still open
                            setState(() => _isImporting = true);
                            // Small delay to show the loading indicator
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            Navigator.of(context).pop();
                            _importGeoJsonRouteInternal();
                          },
                        ),
                        ListTile(
                          leading: _isExporting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.download,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          title: Text(
                            _isExporting
                                ? 'Exporterar GeoJSON...'
                                : 'Exportera GeoJSON',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          enabled: !_isImporting && !_isExporting,
                          onTap: () async {
                            // Set loading state first while drawer is still open
                            setState(() => _isExporting = true);
                            // Small delay to show the loading indicator
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
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
                          leading: _isImporting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.upload_file,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          title: Text(
                            _isImporting
                                ? 'Importerar GPX...'
                                : 'Importera GPX',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          enabled: !_isImporting && !_isExporting,
                          onTap: () async {
                            // Set loading state first while drawer is still open
                            setState(() => _isImporting = true);
                            // Small delay to show the loading indicator
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            Navigator.of(context).pop();
                            _importGpxRoute();
                          },
                        ),
                        ListTile(
                          leading: _isExporting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.download,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          title: Text(
                            _isExporting
                                ? 'Exporterar GPX...'
                                : 'Exportera GPX',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          enabled: !_isImporting && !_isExporting,
                          onTap: () async {
                            // Set loading state first while drawer is still open
                            setState(() => _isExporting = true);
                            // Small delay to show the loading indicator
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
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
                        Icons.terrain,
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
                    ListTile(
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
                        '${_savedRoutes.length}/50 rutter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.help,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: _showSavedRoutesHelpDialog,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Information om sparade rutter',
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).pop(); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SavedRoutesPage(
                              routeService: _routeService,
                              onLoadRoute: _loadRouteFromList,
                            ),
                          ),
                        );
                      },
                    ),
                    // Save current route button
                    ListTile(
                      leading: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.add,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      title: Text(
                        _isSaving ? 'Sparar rutt...' : 'Spara aktuell rutt',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      enabled: _routePoints.isNotEmpty && !_isSaving,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showSaveRouteDialog();
                      },
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
                        if (_buildNumber.isNotEmpty) {
                          parts.add('#$_buildNumber');
                        }
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
                    () {
                      final dynamicSize = _calculateDynamicPointSize();
                      return Marker(
                        point: _routePoints[i],
                        width: dynamicSize,
                        height: dynamicSize,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => setState(() => _editingIndex = i),
                          onLongPress: () => _deletePoint(i),
                          child: PointMarker(
                            index: i,
                            isEditing: _editingIndex == i,
                            size:
                                dynamicSize *
                                0.8, // Make inner point slightly smaller
                          ),
                        ),
                      );
                    }(),
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
                  DistancePanel(
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
    // Point size calculation is handled in build method via _calculateDynamicPointSize()
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

    setState(() => _isExporting = true);

    try {
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
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importGeoJsonRouteInternal() async {
    try {
      print('Opening file picker');
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['geojson', 'json'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        print('No file selected or picker cancelled');
        return;
      }

      print('File selected, processing...');
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
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
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

    setState(() => _isExporting = true);

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
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importGpxRoute() async {
    setState(() => _isImporting = true);

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
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}
