import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Import our components
import '../models/saved_route.dart';
import '../models/route_state_snapshot.dart';
import '../widgets/info_overlay.dart';
import '../widgets/distance_panel.dart';
import '../widgets/gravel_app_drawer.dart';
import '../widgets/gravel_app_bar.dart';
import '../widgets/save_route_dialog.dart';
import '../widgets/drawer_footer.dart';
import '../widgets/layers/start_stop_markers_layer.dart';
import '../widgets/layers/user_location_layer.dart';
import '../widgets/layers/distance_markers_layers.dart';
import '../widgets/layers/route_points_layer.dart';
import '../widgets/layers/midpoint_add_markers_layer.dart';
import '../providers/service_providers.dart';
import '../screens/saved_routes_page.dart';
import '../providers/ui_providers.dart';
import '../providers/loading_providers.dart';
import '../mixins/file_operations_mixin.dart';
import '../mixins/map_operations_mixin.dart';
import '../mixins/route_management_mixin.dart';
import '../mixins/saved_routes_mixin.dart';
import '../mixins/distance_markers_mixin.dart';
import '../services/gravel_overpass_service.dart';
import '../widgets/overlays/file_operation_overlay.dart';
import '../widgets/overlays/watermark.dart';
import '../widgets/overlays/bottom_controls_panel.dart';

class GravelStreetsMap extends ConsumerStatefulWidget {
  const GravelStreetsMap({super.key});
  @override
  ConsumerState<GravelStreetsMap> createState() => _GravelStreetsMapState();
}

class _GravelStreetsMapState extends ConsumerState<GravelStreetsMap>
    with
        TickerProviderStateMixin,
        FileOperationsMixin,
        MapOperationsMixin,
        RouteManagementMixin,
        SavedRoutesMixin,
        DistanceMarkersMixin {
  // Data
  List<Polyline> gravelPolylines = [];
  final GravelOverpassService _overpassService = GravelOverpassService();
  // Note: _showGravelOverlay is now managed by gravelOverlayProvider
  final bool _showTrvNvdbOverlay =
      false; // Disabled by default, prepared for future
  bool isLoading = true;
  LatLng? _myPosition;
  Timer? _moveDebounce;
  LatLngBounds? _lastFetchedBounds;
  LatLngBounds? _lastEventBounds;
  // Map control
  final MapController _mapController = MapController();

  // Implement abstract method from MapOperationsMixin
  @override
  LatLngBounds getCurrentBounds() {
    final camera = _mapController.camera;
    return camera.visibleBounds;
  }

  double? _lastZoom;
  // CI/CD build number (provided via --dart-define=BUILD_NUMBER=123), empty locally
  final String _buildNumber = const String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );
  // App version from pubspec.yaml
  String _appVersion = '';
  // Package name for User-Agent (required by OSM tile policy on native)
  String _userAgentPackageName = 'com.aoli.gravelfirst';
  // Optional MapTiler key for production-friendly tiles (web and mobile)
  final String _mapTilerKey = const String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );

  // Measurement
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  // Note: _measureEnabled is now managed by measureModeProvider
  // Note: _loopClosed is now managed by routeNotifierProvider
  bool _editModeEnabled = false;
  // Distance markers state
  final List<LatLng> _distanceMarkers = [];
  LatLng? _routeMidpoint; // Single midpoint marker at half total distance
  // Distance markers visibility managed by distanceMarkersProvider
  bool _showSegmentAnalysis =
      false; // Default OFF - hide segment analysis panel
  // Distance interval managed by distanceIntervalProvider

  // Editing index managed by editingIndexProvider
  bool _isInitialized = false; // Track RouteService initialization status
  bool _isInitialFetchComplete =
      false; // Prevent duplicate API calls during initialization
  // Current route name (shown as floating label on the map)
  String? _currentRouteName;
  // Autosave support
  Timer? _autosaveTimer;
  bool _isAutosaving = false;
  SavedRoute?
  _autosavedRouteRef; // Track the route created/overwritten by autosave

  // Expose storage initialization status to SavedRoutesMixin
  @override
  bool get isStorageInitialized => _isInitialized;

  // DistanceMarkersMixin bindings
  @override
  List<LatLng> get routePoints => _routePoints;
  @override
  List<LatLng> get distanceMarkers => _distanceMarkers;
  @override
  Distance get distance => _distance;
  @override
  void saveStateForUndo() => _saveStateForUndo();
  @override
  void requestRebuild() => setState(() {});

  // Global loading overlay for file operations computed from providers

  // Undo system for general edit operations
  final List<RouteStateSnapshot> _undoHistory = [];
  static const int _maxUndoHistory = 50;

  // Dynamic point sizing based on route point density
  // This system automatically adjusts marker sizes to prevent visual overlap in dense routes
  // Saved routes handled by SavedRoutesMixin

  @override
  void initState() {
    super.initState();
    final initTime = DateTime.now();
    debugPrint(
      '🚀 [${initTime.toIso8601String()}] GravelStreetsMap initializing...',
    );

    debugPrint(
      'MapTiler Key: "$_mapTilerKey"',
    ); // Debug: Check if key is loaded
    _loadAppVersion();
    _initializeServices();
    // Initial fetch for a sensible area (Stockholm bbox)
    debugPrint(
      '🗺️ [${initTime.toIso8601String()}] Requesting initial gravel data for Stockholm area',
    );
    _fetchGravelForBounds(
      LatLngBounds(const LatLng(59.3, 18.0), const LatLng(59.4, 18.1)),
      isInitialFetch: true, // Mark as initial fetch to prevent duplicates
    );
  }

  // ---- Autosave helpers ----
  String _makeTempRouteName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final y = now.year;
    final m = two(now.month);
    final d = two(now.day);
    final h = two(now.hour);
    final min = two(now.minute);
    return 'Route $y-$m-$d $h:$min';
  }

  void _startAutosaveTimerIfNeeded() {
    // Only start if not running, we have at least one point, and we have a name
    if (_autosaveTimer != null) return;
    if (_routePoints.isEmpty) return;
    if (_currentRouteName == null || _currentRouteName!.isEmpty) return;
    _autosaveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _autosaveTick();
    });
    debugPrint('🕒 Autosave: started');
  }

  Future<void> _autosaveTick() async {
    if (!mounted) return;
    if (_isAutosaving) return; // Prevent re-entry
    if (_routePoints.isEmpty) return; // Nothing to save
    if (_currentRouteName == null || _currentRouteName!.isEmpty) return;

    // Ensure storage is initialized and available
    final routeService = ref.read(routeServiceProvider);
    if (!isStorageInitialized || !routeService.isStorageAvailable()) {
      return; // Silent skip when storage unavailable
    }

    _isAutosaving = true;
    try {
      final syncedService = ref.read(syncedRouteServiceProvider);

      // Overwrite previously autosaved route if available; otherwise create/find by name
      if (_autosavedRouteRef != null) {
        _autosavedRouteRef = await syncedService.overwriteRoute(
          existingRoute: _autosavedRouteRef!,
          routePoints: _routePoints,
          loopClosed: ref.read(loopClosedProvider),
          isPublic: false, // always private for autosave
        );
        debugPrint('✅ Autosave: overwritten "${_autosavedRouteRef!.name}"');
      } else {
        // Attempt to find an existing route by the same name to overwrite
        final existing = await syncedService.findRouteByName(
          _currentRouteName!,
        );
        if (existing != null) {
          _autosavedRouteRef = await syncedService.overwriteRoute(
            existingRoute: existing,
            routePoints: _routePoints,
            loopClosed: ref.read(loopClosedProvider),
            isPublic: false,
          );
          debugPrint('✅ Autosave: overwritten existing "${existing.name}"');
        } else {
          _autosavedRouteRef = await syncedService.saveCurrentRoute(
            name: _currentRouteName!,
            routePoints: _routePoints,
            loopClosed: ref.read(loopClosedProvider),
            description: null,
            isPublic: false,
          );
          debugPrint('✅ Autosave: created "${_autosavedRouteRef!.name}"');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Autosave failed: $e');
    } finally {
      _isAutosaving = false;
    }
  }

  void _stopAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _autosavedRouteRef = null; // Reset reference when clearing route
    debugPrint('🕒 Autosave: stopped');
  }

  Future<void> _initializeServices() async {
    final startTime = DateTime.now();
    debugPrint(
      '⚙️ [${startTime.toIso8601String()}] Starting service initialization...',
    );

    try {
      // Initialize authentication first (background, non-blocking)
      debugPrint(
        '🔐 [${DateTime.now().toIso8601String()}] Initializing authentication...',
      );
      ref.read(authInitializationProvider);

      // Wait for RouteService to be initialized through the provider
      await ref.read(routeServiceInitializedProvider.future);

      // With graceful degradation, initialization should always succeed
      // Check actual storage availability instead
      final routeService = ref.read(routeServiceProvider);
      debugPrint(
        '🔍 [${DateTime.now().toIso8601String()}] Checking storage availability...',
      );
      final storageAvailable = routeService.isStorageAvailable();
      debugPrint(
        '📊 [${DateTime.now().toIso8601String()}] Storage available: $storageAvailable',
      );

      // Log detailed storage diagnostics
      final diagnostics = routeService.getStorageDiagnostics();
      debugPrint(
        '🔧 [${DateTime.now().toIso8601String()}] Storage diagnostics:',
      );
      for (final line in diagnostics.split('\n')) {
        if (line.trim().isNotEmpty) {
          debugPrint('   $line');
        }
      }

      if (storageAvailable) {
        await loadSavedRoutes();
        debugPrint('✅ Storage working - routes loaded successfully');
      } else {
        debugPrint(
          '⚠️ Storage disabled - app continues with limited functionality',
        );
        // Show a non-intrusive info message instead of error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Route saving disabled (private browsing or storage blocked). App functions normally otherwise.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '✅ [${DateTime.now().toIso8601String()}] Service initialization completed in ${duration.inMilliseconds}ms (storage: ${storageAvailable ? 'enabled' : 'disabled'})',
      );
      setState(() {
        _isInitialized =
            true; // Always set to true - app should work regardless of storage
      });
    } catch (e) {
      final errorTime = DateTime.now();
      final duration = errorTime.difference(startTime);
      debugPrint(
        '❌ [${errorTime.toIso8601String()}] Service initialization FAILED after ${duration.inMilliseconds}ms: ${e.runtimeType} - $e',
      );
      setState(() {
        _isInitialized = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected initialization error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Försök igen',
              onPressed: () async {
                debugPrint('_initializeServices: Manual retry triggered');
                await _initializeServices();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      // Prefer the real package name when available
      if (packageInfo.packageName.isNotEmpty) {
        _userAgentPackageName = packageInfo.packageName;
      }
    });
  }

  // Saved Routes Management
  // Delegated to SavedRoutesMixin.saveCurrentRoute

  /// Load route from SavedRoutesPage - no navigation pops needed
  void _loadRouteFromSavedRoute(SavedRoute savedRoute) {
    setState(() {
      _routePoints.clear();
      _distanceMarkers.clear(); // Clear distance markers when loading new route
      _routePoints.addAll(savedRoute.latLngPoints);
      _segmentMeters.clear();
      _currentRouteName = savedRoute.name;
      ref.read(editingIndexProvider.notifier).state = null;
      ref
          .read(routeNotifierProvider.notifier)
          .setLoopClosed(
            savedRoute.loopClosed,
          ); // Properly restore the loop state

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
      autoRecalcDistanceMarkers(); // Auto-generate distance markers for loaded route
    }
  }

  // Legacy method removed; use _loadRouteFromSavedRoute for loading routes

  void _centerMapOnRoute() => centerMapOnRoute(_mapController, _routePoints);

  // Old inline dialogs removed - use extracted widgets

  void _onMapEvent(MapEvent event) {
    // Debounce on any map movement/zoom/rotate event
    _lastEventBounds = event.camera.visibleBounds;
    _lastZoom = event.camera.zoom;
    _moveDebounce?.cancel();
    debugPrint(
      '🔄 [${DateTime.now().toIso8601String()}] Map moved, debouncing for 1000ms (zoom: ${event.camera.zoom.toStringAsFixed(2)})',
    );
    _moveDebounce = Timer(
      const Duration(
        milliseconds: 1000,
      ), // Increased from 500ms to reduce API calls
      _queueViewportFetch,
    );
  }

  void _queueViewportFetch() {
    final timestamp = DateTime.now();
    final bounds = _lastEventBounds;
    if (bounds == null) {
      debugPrint(
        '⚠️ [${timestamp.toIso8601String()}] Queue fetch cancelled - no bounds available',
      );
      return;
    }
    // Remove the duplicate bounds check here since it's now handled in _fetchGravelForBounds
    _fetchGravelForBounds(bounds); // This is a non-initial fetch
  }

  bool _boundsAlmostEqual(
    LatLngBounds a,
    LatLngBounds b, {
    double tol = 0.0005,
  }) => boundsAlmostEqual(a, b, tol: tol);

  Future<void> _fetchGravelForBounds(
    LatLngBounds bounds, {
    bool isInitialFetch = false,
  }) async {
    // Prevent duplicate initial fetches
    if (isInitialFetch) {
      if (_isInitialFetchComplete) {
        debugPrint(
          '⏭️ [${DateTime.now().toIso8601String()}] Skipping duplicate initial fetch',
        );
        return;
      }
      _isInitialFetchComplete = true;
    }

    // Prevent duplicate non-initial fetches with bounds comparison
    if (!isInitialFetch &&
        _lastFetchedBounds != null &&
        _boundsAlmostEqual(_lastFetchedBounds!, bounds)) {
      debugPrint(
        '⏭️ [${DateTime.now().toIso8601String()}] Queue fetch skipped - bounds almost equal to last fetch',
      );
      return;
    }

    _lastFetchedBounds = bounds;

    final timestamp = DateTime.now();
    debugPrint('🌐 [${timestamp.toIso8601String()}] Gravel fetch requested');
    debugPrint(
      '📍 Bounds: ${bounds.southWest.latitude.toStringAsFixed(4)},${bounds.southWest.longitude.toStringAsFixed(4)} to ${bounds.northEast.latitude.toStringAsFixed(4)},${bounds.northEast.longitude.toStringAsFixed(4)}',
    );
    final result = await _overpassService.fetchPolylinesForBounds(
      bounds,
      appVersion: _appVersion,
    );
    if (result != null) {
      if (!mounted) return;
      setState(() {
        gravelPolylines = result;
        isLoading = false;
      });
      debugPrint(
        '✨ [${DateTime.now().toIso8601String()}] Gravel data updated successfully',
      );
    } else {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer MapTiler for production reliability and compliance
    final useMapTiler = _mapTilerKey.isNotEmpty;
    final tileUrl = useMapTiler
        ? 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
        : 'https://tile.openstreetMap.org/{z}/{x}/{y}.png'; // No subdomains to avoid warning
    final subdomains = const <String>[]; // Avoid subdomains entirely
    final attribution = useMapTiler
        ? '© MapTiler © OpenStreetMap contributors'
        : '© OpenStreetMap contributors';

    return Scaffold(
      appBar: GravelAppBar(onLocateMe: _locateMe),
      drawer: GravelAppDrawer(
        onImportGeoJson: () async {
          await importGeoJsonRoute((points, loopClosed) {
            setState(() {
              _routePoints
                ..clear()
                ..addAll(points);
              _currentRouteName = null; // Unknown name after import
              ref.read(editingIndexProvider.notifier).state = null;
              ref
                  .read(routeNotifierProvider.notifier)
                  .setLoopClosed(loopClosed && _routePoints.length >= 3);
              _recomputeSegments();
            });

            if (_routePoints.isNotEmpty) {
              _centerMapOnRoute();
              autoRecalcDistanceMarkers();
            }
          });
        },
        onExportGeoJson: () async {
          await exportGeoJsonRoute(_routePoints);
        },
        onImportGpx: () async {
          await importGpxRoute((points, loopClosed) {
            setState(() {
              _routePoints
                ..clear()
                ..addAll(points);
              _currentRouteName = null; // Unknown name after import
              ref.read(editingIndexProvider.notifier).state = null;
              ref
                  .read(routeNotifierProvider.notifier)
                  .setLoopClosed(loopClosed);
              if (_routePoints.length > 1000) {
                _segmentMeters.clear();
              } else {
                _recomputeSegments();
              }
            });

            if (_routePoints.length > 1000) {
              Future.delayed(
                const Duration(milliseconds: 100),
                _recomputeSegmentsAsync,
              );
            }

            if (_routePoints.isNotEmpty) {
              _centerMapOnRoute();
              autoRecalcDistanceMarkers();
            }
          });
        },
        onExportGpx: () async {
          await exportGpxRoute(_routePoints);
        },
        onSaveRoute: (name, isPublic) =>
            saveCurrentRoute(name, _routePoints, isPublic: isPublic).then((_) {
              if (mounted) {
                setState(() => _currentRouteName = name);
              }
            }),
        hasRoute: _routePoints.isNotEmpty,
        savedRoutesCount: savedRoutes.length,
        maxSavedRoutes: maxSavedRoutes,
        distanceMarkers: _distanceMarkers,
        showTrvNvdbOverlay: _showTrvNvdbOverlay,
        // Segment analysis toggle
        onToggleSegmentAnalysis: (v) =>
            setState(() => _showSegmentAnalysis = v),
        showSegmentAnalysis: _showSegmentAnalysis,
        onToggleDistanceMarkers: (v) =>
            ref.read(distanceMarkersProvider.notifier).state = v,
        onGenerateDistanceMarkers: _routePoints.length < 2
            ? () {}
            : () {
                recalcDistanceMarkers();
              },
        onClearDistanceMarkers: _distanceMarkers.isEmpty
            ? () {}
            : () => setState(() => _distanceMarkers.clear()),
        onSavedRoutesTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SavedRoutesPage(
                onLoadRoute: _loadRouteFromSavedRoute,
                onRoutesChanged: loadSavedRoutes,
              ),
            ),
          );
        },
        footer: DrawerFooter(
          appVersion: _appVersion,
          buildNumber: _buildNumber,
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
                if (!ref.read(measureModeProvider)) return;
                setState(() {
                  final editingIndex = ref.read(editingIndexProvider);
                  if (editingIndex != null) {
                    // Save state before moving point
                    _saveStateForUndo();
                    // Move selected point to this location
                    _routePoints[editingIndex] = latLng;
                    ref.read(editingIndexProvider.notifier).state = null;
                    _recomputeSegments();
                    // Always regenerate distance markers when moving a waypoint
                    // to ensure they stay positioned correctly along the updated polyline
                    autoRecalcDistanceMarkers();
                  } else if (!_editModeEnabled) {
                    // Save state before adding new point
                    _saveStateForUndo();
                    // Only allow adding new points when edit mode is disabled
                    // This prevents accidentally adding points while trying to edit existing ones
                    if (ref.watch(loopClosedProvider)) {
                      ref
                          .read(routeNotifierProvider.notifier)
                          .setLoopClosed(false); // re-open when adding
                    }
                    final wasEmpty = _routePoints.isEmpty;
                    _routePoints.add(latLng);
                    _recomputeSegments();
                    autoRecalcDistanceMarkers(); // Always generate distance markers

                    // If this is the first point of a new route, request a name and start autosave
                    if (wasEmpty) {
                      if (_currentRouteName == null ||
                          _currentRouteName!.isEmpty) {
                        final temp = _makeTempRouteName();
                        _currentRouteName = temp; // Set default immediately
                        // Fire-and-forget a minimal name dialog (private-only)
                        // Use SaveRouteDialog with isAuthenticated=false to hide visibility toggle
                        // If the user cancels, we keep the temporary name
                        Future.microtask(() {
                          if (!context.mounted) return;
                          // Fire dialog without awaiting to avoid using context across async gaps
                          SaveRouteDialog.show(
                            context,
                            onSave: (name, _) async {
                              if (!mounted) return;
                              setState(() => _currentRouteName = name.trim());
                            },
                            savedRoutesCount: savedRoutes.length,
                            maxSavedRoutes: maxSavedRoutes,
                            isAuthenticated:
                                false, // force private-only for this prompt
                            initialName: temp,
                          );
                        });
                      }
                      // Ensure autosave starts
                      _startAutosaveTimerIfNeeded();
                    }
                  }
                  // When edit mode is enabled but no point is selected, do nothing
                  // This prevents accidental point addition during editing
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: subdomains,
                maxZoom: 19,
                userAgentPackageName: _userAgentPackageName,
              ),
              if (ref.watch(gravelOverlayProvider))
                PolylineLayer(polylines: gravelPolylines),
              PolylineLayer(
                polylines: [
                  if (_routePoints.length >= 2)
                    Polyline(
                      points:
                          ref.watch(loopClosedProvider) &&
                              _routePoints.length >= 3
                          ? [..._routePoints, _routePoints.first]
                          : _routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3,
                    ),
                ],
              ),
              UserLocationLayer(position: _myPosition),
              // Start/stop markers - shown in both view mode and when creating routes
              if (_routePoints.length >= 2)
                StartStopMarkersLayer(
                  routePoints: _routePoints,
                  isLoopClosed: ref.watch(loopClosedProvider),
                ),
              RoutePointsLayer(
                points: _routePoints,
                measureEnabled: ref.watch(measureModeProvider),
                editModeEnabled: _editModeEnabled,
                lastZoom: _lastZoom,
                isLoopClosed: ref.watch(loopClosedProvider),
                isEditingIndex: ref.watch(editingIndexProvider),
                onTapPoint: (i) {
                  if (_editModeEnabled) {
                    ref.read(editingIndexProvider.notifier).state = i;
                  } else {
                    _showDistanceToPoint(i);
                  }
                },
                onLongPressPoint: (i) {
                  if (_editModeEnabled) {
                    _showDeletePointConfirmation(i);
                  }
                },
              ),
              // Midpoint markers for adding points between existing points
              if (_editModeEnabled && _routePoints.length >= 2)
                MidpointAddMarkersLayer(
                  routePoints: _routePoints,
                  loopClosed: ref.watch(loopClosedProvider),
                  onAddBetween: _addPointBetween,
                ),
              // Distance markers layer - shown only when toggle is enabled
              if (ref.watch(distanceMarkersProvider) &&
                  _distanceMarkers.isNotEmpty)
                DistanceMarkersLayer(
                  markers: _distanceMarkers,
                  intervalMeters: ref.watch(distanceIntervalProvider),
                  onTap: (index, km) => _showDistanceMarkerInfo(index, km),
                ),
              // Half-distance markers layer - shown with distance markers
              if (ref.watch(distanceMarkersProvider) && _routeMidpoint != null)
                RouteMidpointMarkerLayer(
                  midpointLocation: _routeMidpoint,
                  totalDistanceKm: _formatTotalDistanceKm(),
                ),
              // Distance marker dots - always visible on polyline
            ],
          ),
          // Route segments panel at the top - conditionally displayed
          if (_showSegmentAnalysis)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: RouteSegmentsPanel(
                segmentMeters: _segmentMeters,
                loopClosed: ref.watch(loopClosedProvider),
                theme: Theme.of(context),
              ),
            ),
          // Floating current route name chip (top-left)
          if (_currentRouteName != null && _currentRouteName!.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.5,
                      ),
                      child: Text(
                        _currentRouteName!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Total distance display in top right corner
          if (_routePoints.length >= 2 && _segmentMeters.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTotalDistance(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Minimal attribution to meet OSM/MapTiler requirements
          Positioned(
            bottom: 4,
            left: 12,
            right: 12,
            child: Text(
              attribution,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          // Global file operation loading overlay
          FileOperationOverlay(
            isImporting: ref.watch(isImportingProvider),
            isExporting: ref.watch(isExportingProvider),
          ),
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
          BottomControlsPanel(
            segmentMeters: _segmentMeters,
            onUndo: _undoLastEdit,
            onSave: () async {
              if (_routePoints.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingen rutt att spara')),
                );
                return;
              }
              // Trigger the dialog without awaiting to avoid using context across async gaps
              SaveRouteDialog.show(
                context,
                onSave: (name, isPublic) async {
                  await saveCurrentRoute(
                    name,
                    _routePoints,
                    isPublic: isPublic,
                  );
                  if (mounted) {
                    setState(() => _currentRouteName = name);
                  }
                },
                savedRoutesCount: savedRoutes.length,
                maxSavedRoutes: maxSavedRoutes,
                isAuthenticated: ref.watch(isSignedInProvider),
                initialName: _currentRouteName,
              );
            },
            onClear: _showClearRouteConfirmation,
            onEditModeChanged: (enabled) => setState(() {
              _editModeEnabled = enabled;
              if (!enabled) {
                ref.read(editingIndexProvider.notifier).state = null;
              }
            }),
            measureEnabled: ref.watch(measureModeProvider),
            loopClosed: ref.watch(loopClosedProvider),
            canToggleLoop: _routePoints.length >= 3,
            onToggleLoop: _toggleLoop,
            editModeEnabled: _editModeEnabled,
            showDistanceMarkers: ref.watch(distanceMarkersProvider),
            onDistanceMarkersToggled: (enabled) {
              ref.read(distanceMarkersProvider.notifier).state = enabled;
              if (enabled &&
                  _routePoints.length >= 2 &&
                  _distanceMarkers.isEmpty) {
                recalcDistanceMarkers();
              }
            },
            distanceInterval: ref.watch(distanceIntervalProvider),
            canUndo: _undoHistory.isNotEmpty,
            onToggleMeasure: () {
              final currentMode = ref.read(measureModeProvider);
              ref.read(measureModeProvider.notifier).state = !currentMode;

              // If switching to View mode (measure disabled), turn off edit mode
              if (currentMode) {
                // currentMode was true, now becoming false
                setState(() {
                  _editModeEnabled = false;
                  ref.read(editingIndexProvider.notifier).state = null;
                });
              }
            },
          ),
          // Subtle build/version watermark (e.g., v1.2.3 #27)
          VersionWatermark(appVersion: _appVersion, buildNumber: _buildNumber),
          // Floating route name chip (top-left)
          // (optional enhancement can be added later if desired)
        ],
      ),
    );
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _stopAutosaveTimer();
    super.dispose();
  }

  void _saveStateForUndo() {
    final currentState = RouteStateSnapshot.fromCurrent(
      routePoints: _routePoints,
      loopClosed: ref.read(loopClosedProvider),
      showDistanceMarkers: ref.read(distanceMarkersProvider),
      distanceMarkers: _distanceMarkers,
    );

    _undoHistory.add(currentState);

    // Limit history size to prevent memory issues
    if (_undoHistory.length > _maxUndoHistory) {
      _undoHistory.removeAt(0);
    }
  }

  void _undoLastEdit() {
    if (_undoHistory.isEmpty) return;

    final previousState = _undoHistory.removeLast();

    setState(() {
      _routePoints.clear();
      _routePoints.addAll(previousState.routePoints);
      ref
          .read(routeNotifierProvider.notifier)
          .setLoopClosed(previousState.loopClosed);
      ref.read(distanceMarkersProvider.notifier).state =
          previousState.showDistanceMarkers;
      _distanceMarkers.clear();
      _distanceMarkers.addAll(previousState.distanceMarkers);
      ref.read(editingIndexProvider.notifier).state =
          null; // Clear any active editing
      _recomputeSegments();
    });
  }

  void _clearRoute() {
    if (_routePoints.isEmpty && _segmentMeters.isEmpty) return;
    setState(() {
      _routePoints.clear();
      _distanceMarkers.clear(); // Clear distance markers when clearing route
      _segmentMeters.clear();
      _currentRouteName =
          null; // Clear current route name when route is cleared
      ref.read(routeNotifierProvider.notifier).setLoopClosed(false);
      ref.read(editingIndexProvider.notifier).state = null;
      // Keep distance markers toggle state (default OFF for subtle orange dots)
    });
    _stopAutosaveTimer();
  }

  void _showClearRouteConfirmation() {
    if (_routePoints.isEmpty && _segmentMeters.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rensa rutt'),
          content: const Text(
            'Är du säker på att du vill rensa hela rutten? Detta går inte att ångra.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearRoute();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Rensa'),
            ),
          ],
        );
      },
    );
  }

  void _addPointBetween(int beforeIndex, int afterIndex, LatLng midpoint) {
    _saveStateForUndo(); // Save state before adding midpoint
    setState(() {
      if (afterIndex == 0 && beforeIndex == _routePoints.length - 1) {
        // Adding between last and first point (loop closure)
        _routePoints.add(midpoint);
      } else {
        // Adding between consecutive points
        _routePoints.insert(afterIndex, midpoint);
      }
      _recomputeSegments();
      autoRecalcDistanceMarkers(); // Always regenerate distance markers
      // Keep edit mode active and select the new point
      if (afterIndex == 0 && beforeIndex == _routePoints.length - 2) {
        ref.read(editingIndexProvider.notifier).state =
            _routePoints.length - 1; // New point at end
      } else {
        ref.read(editingIndexProvider.notifier).state =
            afterIndex; // New point at insertion position
      }
    });
  }

  void _toggleLoop() {
    if (_routePoints.length < 3) return;
    _saveStateForUndo(); // Save state before toggling loop
    setState(() {
      ref.read(routeNotifierProvider.notifier).toggleLoop();
      _recomputeSegments();
      // Always regenerate distance markers when toggling loop state
      // This ensures markers are generated for the closing segment
      autoRecalcDistanceMarkers();
    });
  }

  void _recomputeSegments() {
    _segmentMeters
      ..clear()
      ..addAll(_computeSegments(_routePoints, ref.read(loopClosedProvider)));
    // Point size calculation is handled in build method via _calculateDynamicPointSize()
  }

  /// Async version for large routes to prevent UI freezing
  Future<void> _recomputeSegmentsAsync() async {
    if (!mounted) return;

    final segments = <double>[];
    final points = _routePoints;
    final closed = ref.read(loopClosedProvider);

    if (points.length < 2) return;

    // Process in chunks to prevent UI freeze
    const chunkSize = 200;
    for (int start = 1; start < points.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, points.length);

      for (int i = start; i < end; i++) {
        segments.add(_distance.as(LengthUnit.Meter, points[i - 1], points[i]));
      }

      // Yield control back to the UI thread periodically
      if (start % (chunkSize * 5) == 1) {
        await Future.delayed(const Duration(milliseconds: 1));
        if (!mounted) return; // Check if widget is still mounted
      }
    }

    // Handle closing segment for loops
    if (closed && points.length >= 3) {
      segments.add(_distance.as(LengthUnit.Meter, points.last, points.first));
    }

    // Update UI with computed segments
    if (mounted) {
      setState(() {
        _segmentMeters
          ..clear()
          ..addAll(segments);
      });
    }
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

  /// Distance markers are recalculated by DistanceMarkersMixin

  void _showDeletePointConfirmation(int index) {
    if (index < 0 || index >= _routePoints.length) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ta bort punkt'),
          content: Text(
            'Är du säker på att du vill ta bort punkt ${index + 1}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePoint(index);
              },
              child: const Text('Ta bort'),
            ),
          ],
        );
      },
    );
  }

  void _showDistanceToPoint(int index) {
    if (index < 0 || index >= _routePoints.length) return;

    // Calculate distance from start (point 0) to the selected point
    double distanceFromStart = 0.0;
    for (int i = 0; i < index; i++) {
      distanceFromStart += _distance.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
    }
    String formattedDistance;
    if (distanceFromStart >= 1000) {
      formattedDistance = '${(distanceFromStart / 1000).toStringAsFixed(2)}km';
    } else {
      formattedDistance = '${distanceFromStart.toInt()}m';
    }

    InfoOverlay.show(
      context,
      text: 'P${index + 1} $formattedDistance från Start',
      borderColor: Theme.of(context).colorScheme.primary,
    );
  }

  void _showDistanceMarkerInfo(int markerIndex, double distanceKm) {
    String formattedDistance;
    if (distanceKm < 1) {
      formattedDistance = '${(distanceKm * 1000).toInt()}m';
    } else {
      formattedDistance = '${distanceKm.toStringAsFixed(1)}km'.replaceAll(
        '.0km',
        'km',
      );
    }

    InfoOverlay.show(
      context,
      text: 'Avståndsmarkering $formattedDistance från Start',
      borderColor: Colors.orange,
    );
  }

  void _deletePoint(int index) {
    if (index < 0 || index >= _routePoints.length) return;
    _saveStateForUndo(); // Save state before deleting point
    setState(() {
      _routePoints.removeAt(index);
      _distanceMarkers.clear(); // Clear distance markers when modifying route
      if (_routePoints.length < 3) {
        ref.read(routeNotifierProvider.notifier).setLoopClosed(false);
      }
      final currentEditingIndex = ref.read(editingIndexProvider);
      if (currentEditingIndex != null) {
        if (_routePoints.isEmpty) {
          ref.read(editingIndexProvider.notifier).state = null;
        } else if (index == currentEditingIndex) {
          ref.read(editingIndexProvider.notifier).state = null;
        } else if (index < currentEditingIndex) {
          ref.read(editingIndexProvider.notifier).state =
              currentEditingIndex - 1;
        }
      }
      _recomputeSegments();
      autoRecalcDistanceMarkers(); // Always regenerate distance markers
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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

  /// Override to generate distance markers and route midpoint
  @override
  void recalcDistanceMarkers() {
    if (_routePoints.length < 2) return;

    saveStateForUndo();
    _distanceMarkers.clear();
    _routeMidpoint = null;

    final intervalMeters = ref.read(distanceIntervalProvider); // in meters

    // Calculate total route distance first to find midpoint
    double totalRouteDistance = 0.0;
    for (int i = 1; i < _routePoints.length; i++) {
      totalRouteDistance += _distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
    }

    // Add closing segment distance if loop is closed
    if (ref.read(loopClosedProvider) && _routePoints.length >= 3) {
      totalRouteDistance += _distance.as(
        LengthUnit.Meter,
        _routePoints.last,
        _routePoints.first,
      );
    }

    final halfTotalDistance = totalRouteDistance / 2.0;

    double currentDistance = 0.0;
    double nextMainMarkerDistance = intervalMeters;
    bool midpointFound = false;

    for (int i = 1; i < _routePoints.length; i++) {
      final segmentDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + segmentDistance;

      // Place main markers within this segment
      while (nextMainMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMainMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / segmentDistance;

        final lat =
            _routePoints[i - 1].latitude +
            ((_routePoints[i].latitude - _routePoints[i - 1].latitude) * ratio);
        final lon =
            _routePoints[i - 1].longitude +
            ((_routePoints[i].longitude - _routePoints[i - 1].longitude) *
                ratio);

        _distanceMarkers.add(LatLng(lat, lon));
        nextMainMarkerDistance += intervalMeters;
      }

      // Check if midpoint falls within this segment
      if (!midpointFound &&
          halfTotalDistance >= segmentStart &&
          halfTotalDistance <= segmentEnd) {
        final distanceIntoSegment = halfTotalDistance - segmentStart;
        final ratio = distanceIntoSegment / segmentDistance;

        final lat =
            _routePoints[i - 1].latitude +
            ((_routePoints[i].latitude - _routePoints[i - 1].latitude) * ratio);
        final lon =
            _routePoints[i - 1].longitude +
            ((_routePoints[i].longitude - _routePoints[i - 1].longitude) *
                ratio);

        _routeMidpoint = LatLng(lat, lon);
        midpointFound = true;
      }

      currentDistance = segmentEnd;
    }

    // Handle closed loop - check closing segment for both main and half markers
    if (ref.read(loopClosedProvider) && _routePoints.length >= 3) {
      final closingDistance = _distance.as(
        LengthUnit.Meter,
        _routePoints.last,
        _routePoints.first,
      );
      final segmentStart = currentDistance;
      final segmentEnd = currentDistance + closingDistance;

      // Main markers in closing segment
      while (nextMainMarkerDistance <= segmentEnd) {
        final distanceIntoSegment = nextMainMarkerDistance - segmentStart;
        final ratio = distanceIntoSegment / closingDistance;

        final lat =
            _routePoints.last.latitude +
            ((_routePoints.first.latitude - _routePoints.last.latitude) *
                ratio);
        final lon =
            _routePoints.last.longitude +
            ((_routePoints.first.longitude - _routePoints.last.longitude) *
                ratio);

        _distanceMarkers.add(LatLng(lat, lon));
        nextMainMarkerDistance += intervalMeters;
      }

      // Check if midpoint falls within closing segment
      if (!midpointFound &&
          halfTotalDistance >= segmentStart &&
          halfTotalDistance <= segmentEnd) {
        final distanceIntoSegment = halfTotalDistance - segmentStart;
        final ratio = distanceIntoSegment / closingDistance;

        final lat =
            _routePoints.last.latitude +
            ((_routePoints.first.latitude - _routePoints.last.latitude) *
                ratio);
        final lon =
            _routePoints.last.longitude +
            ((_routePoints.first.longitude - _routePoints.last.longitude) *
                ratio);

        _routeMidpoint = LatLng(lat, lon);
        midpointFound = true;
      }
    }

    // Trigger rebuild
    setState(() {});
  }

  /// Format total route distance for display
  String _formatTotalDistance() {
    if (_segmentMeters.isEmpty) return '0 km';

    final totalMeters = _segmentMeters.reduce((a, b) => a + b);
    final totalKm = totalMeters / 1000.0;

    if (totalKm < 1.0) {
      return '${totalMeters.round()} m';
    }
    // Always show one decimal for kilometer values
    return '${totalKm.toStringAsFixed(1)} km';
  }

  /// Get total route distance in kilometers (for midpoint marker)
  double _formatTotalDistanceKm() {
    if (_segmentMeters.isEmpty) return 0.0;
    final totalMeters = _segmentMeters.reduce((a, b) => a + b);
    return totalMeters / 1000.0;
  }
}
