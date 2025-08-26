import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'package:package_info_plus/package_info_plus.dart';

// Import our refactored components
import '../models/saved_route.dart';
import '../widgets/point_marker.dart';
import '../widgets/distance_panel.dart';
import '../screens/saved_routes_page.dart';
import '../services/route_service.dart';
import '../services/map_service.dart';
import '../services/location_service.dart';
import '../services/file_service.dart';
import '../services/measurement_service.dart';

/// Background isolate function for parsing GPX track points
List<LatLng> _parseGpxPoints(Uint8List data) {
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

  return pts;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Services
  late final MapService _mapService;
  late final LocationService _locationService;
  late final FileService _fileService;
  late final MeasurementService _measurementService;
  late final RouteService _routeService;

  // Map control
  final MapController _mapController = MapController();
  double? _lastZoom;

  // App version info
  String _appVersion = '';
  String _userAgentPackageName = 'com.aoli.gravelfirst';
  final String _buildNumber = const String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );
  final String _mapTilerKey = const String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );

  // Loading states
  final bool _isExporting = false;
  final bool _isImporting = false;
  final bool _isSaving = false;

  // Saved routes
  final List<SavedRoute> _savedRoutes = [];
  static const int _maxSavedRoutes = 50;

  bool get _isFileOperationLoading => _isExporting || _isImporting;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadAppVersion();
    _loadSavedRoutes();
    // Initial fetch for Stockholm area
    _mapService.fetchGravelForBounds(
      LatLngBounds(const LatLng(59.3, 18.0), const LatLng(59.4, 18.1)),
    );
  }

  void _initializeServices() {
    _mapService = MapService();
    _locationService = LocationService();
    _fileService = FileService();
    _measurementService = MeasurementService();
    _routeService = RouteService();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      if (packageInfo.packageName.isNotEmpty) {
        _userAgentPackageName = packageInfo.packageName;
      }
    });

    _mapService.initialize(
      appVersion: _appVersion,
      userAgentPackageName: _userAgentPackageName,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final useMapTiler = _mapTilerKey.isNotEmpty;
    final tileUrl = useMapTiler
        ? 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
        : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    final subdomains = useMapTiler
        ? const <String>[]
        : const <String>['a', 'b', 'c'];
    final attribution = useMapTiler
        ? '© MapTiler © OpenStreetMap contributors'
        : '© OpenStreetMap contributors';

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _buildMapBody(tileUrl, subdomains, attribution),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        _buildLocationButton(),
        _buildMeasurementToggle(),
        _buildClearButton(),
      ],
    );
  }

  Widget _buildLocationButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.secondaryContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
        onPressed: () => _locateMe(),
      ),
    );
  }

  Widget _buildMeasurementToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _measurementService.measureEnabled
            ? Colors.green.shade600
            : Colors.red.shade600,
        border: Border.all(
          color: _measurementService.measureEnabled
              ? Colors.green.shade800
              : Colors.red.shade800,
          width: 2,
        ),
      ),
      child: IconButton(
        tooltip: _measurementService.measureEnabled
            ? 'Stäng av mätläge'
            : 'Aktivera mätläge',
        icon: const Icon(Icons.straighten, color: Colors.white, size: 22),
        onPressed: () {
          setState(() {
            _measurementService.measureEnabled =
                !_measurementService.measureEnabled;
          });
        },
      ),
    );
  }

  Widget _buildClearButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.errorContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.error,
          width: 2,
        ),
      ),
      child: IconButton(
        tooltip: 'Rensa rutt',
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
          size: 22,
        ),
        onPressed: () {
          setState(() {
            _measurementService.clearRoute();
          });
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
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
                  _buildImportExportSection(),
                  _buildOverlaySection(),
                  _buildDistanceMarkersSection(),
                  const Divider(height: 1),
                  _buildSavedRoutesSection(),
                  _buildCloseButton(),
                ],
              ),
            ),
            _buildVersionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody(
    String tileUrl,
    List<String> subdomains,
    String attribution,
  ) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(59.3293, 18.0686),
            initialZoom: 12,
            onMapEvent: _mapService.onMapEvent,
            onTap: (tap, latLng) => _handleMapTap(latLng),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: subdomains,
              maxZoom: 19,
              userAgentPackageName: _userAgentPackageName,
            ),
            if (_showGravelOverlay)
              PolylineLayer(polylines: _mapService.gravelPolylines),
            _buildRoutePolyline(),
            _buildLocationMarker(),
            _buildDistanceMarkers(),
            _buildRouteMarkers(),
            _buildMidpointMarkers(),
          ],
        ),
        _buildRouteSegmentsPanel(),
        _buildAttributionText(attribution),
        if (_mapService.isLoading)
          const Center(child: CircularProgressIndicator()),
        if (_isFileOperationLoading) _buildLoadingOverlay(),
        _buildVersionWatermark(),
        _buildDistancePanel(),
      ],
    );
  }

  void _handleMapTap(LatLng latLng) {
    if (!_measurementService.measureEnabled) return;

    setState(() {
      if (_measurementService.editingIndex != null) {
        _measurementService.moveRoutePoint(
          _measurementService.editingIndex!,
          latLng,
        );
      } else {
        _measurementService.addRoutePoint(latLng);
      }
    });
  }

  Future<void> _locateMe() async {
    final position = await _locationService.locateMe(
      context: context,
      mapController: _mapController,
      lastZoom: _lastZoom,
    );
    if (position != null) {
      setState(() {}); // Trigger rebuild to show position marker
    }
  }

  // Additional helper methods would continue here...
  // This is a simplified version to show the structure

  @override
  void dispose() {
    _mapService.dispose();
    super.dispose();
  }

  // Placeholder methods - these would contain the full implementation
  Widget _buildImportExportSection() => const SizedBox.shrink();
  Widget _buildOverlaySection() => const SizedBox.shrink();
  Widget _buildDistanceMarkersSection() => const SizedBox.shrink();
  Widget _buildSavedRoutesSection() => const SizedBox.shrink();
  Widget _buildCloseButton() => const SizedBox.shrink();
  Widget _buildVersionInfo() => const SizedBox.shrink();
  Widget _buildRoutePolyline() => const SizedBox.shrink();
  Widget _buildLocationMarker() => const SizedBox.shrink();
  Widget _buildDistanceMarkers() => const SizedBox.shrink();
  Widget _buildRouteMarkers() => const SizedBox.shrink();
  Widget _buildMidpointMarkers() => const SizedBox.shrink();
  Widget _buildRouteSegmentsPanel() => const SizedBox.shrink();
  Widget _buildAttributionText(String attribution) => const SizedBox.shrink();
  Widget _buildLoadingOverlay() => const SizedBox.shrink();
  Widget _buildVersionWatermark() => const SizedBox.shrink();
  Widget _buildDistancePanel() => const SizedBox.shrink();

  final bool _showGravelOverlay = true;
}
