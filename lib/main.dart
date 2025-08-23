import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// --- Main App Setup ---
void main() {
  runApp(const MyApp());
}

// Top-level function to parse Overpass JSON and extract polyline coordinates.
// Returns a List of polylines, where each polyline is a List<[lat, lon]> pairs.
List<List<List<double>>> _extractPolylineCoords(String body) {
  final Map<String, dynamic> data = json.decode(body) as Map<String, dynamic>;
  final elements = (data['elements'] as List?) ?? const [];
  final result = <List<List<double>>>[];
  for (final element in elements) {
    if (element is Map &&
        element['type'] == 'way' &&
        element.containsKey('geometry')) {
      final geom = element['geometry'] as List;
      final pts = <List<double>>[];
      for (final node in geom) {
        if (node is Map && node.containsKey('lat') && node.containsKey('lon')) {
          final lat = (node['lat'] as num).toDouble();
          final lon = (node['lon'] as num).toDouble();
          pts.add([lat, lon]);
        }
      }
      if (pts.length >= 2) result.add(pts);
    }
  }
  return result;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel Streets',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GravelStreetsMap(),
    );
  }
}

// --- Map Widget with Data Fetching ---
class GravelStreetsMap extends StatefulWidget {
  const GravelStreetsMap({super.key});

  @override
  State<GravelStreetsMap> createState() => _GravelStreetsMapState();
}

class _GravelStreetsMapState extends State<GravelStreetsMap> {
  List<Polyline> gravelPolylines = [];
  bool isLoading = true;

  // --- Measurement state ---
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  bool _measureEnabled = false;

  @override
  void initState() {
    super.initState();
    fetchGravelStreets();
  }

  Future<void> fetchGravelStreets() async {
    const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';
    // Overpass QL query to find gravel streets in a specific bounding box
    final String query = r'''
      [out:json];
      way
        ["highway"~"^(residential|service|track|unclassified|road)$"]
        ["surface"="gravel"]
        (59.3, 18.0, 59.4, 18.1);
      out geom;
    ''';

    try {
      final response = await http.post(
        Uri.parse(overpassApiUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        // Parse and extract coordinates off the main thread
        final coords = await compute(_extractPolylineCoords, response.body);
        final polylines = <Polyline>[
          for (final pts in coords)
            Polyline(
              points: [for (final p in pts) LatLng(p[0], p[1])],
              color: Colors.brown,
              strokeWidth: 4.0,
            ),
        ];

        if (!mounted) return;
        setState(() {
          gravelPolylines = polylines;
          isLoading = false;
        });
      } else {
        debugPrint('Failed to load gravel streets: ${response.statusCode}');
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the correct map tiles for the current theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String tileUrl = isDark
        ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gravel Streets Map'),
        actions: [
          IconButton(
            tooltip: _measureEnabled
                ? 'Disable measure mode'
                : 'Enable measure mode',
            icon: Icon(
              Icons.straighten,
              color: _measureEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _measureEnabled = !_measureEnabled),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(59.3293, 18.0686),
              initialZoom: 12.0,
              onTap: (tapPosition, latLng) {
                // Add a point and compute segment distance from previous point (if any)
                if (!_measureEnabled) return;
                setState(() {
                  if (_routePoints.isNotEmpty) {
                    final prev = _routePoints.last;
                    final meters = _distance.as(LengthUnit.Meter, prev, latLng);
                    _segmentMeters.add(meters);
                  }
                  _routePoints.add(latLng);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.gravel_biking',
              ),
              PolylineLayer(polylines: gravelPolylines),
              // Measured route polyline
              PolylineLayer(
                polylines: [
                  if (_routePoints.length >= 2)
                    Polyline(
                      points: _routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3.0,
                    ),
                ],
              ),
              // Markers for each selected point
              MarkerLayer(
                markers: [
                  for (int i = 0; i < _routePoints.length; i++)
                    Marker(
                      point: _routePoints[i],
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: _PointMarker(index: i),
                    ),
                ],
              ),
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          // Distance overlay
          Positioned(
            right: 12,
            bottom: 12,
            child: _DistancePanel(
              segmentMeters: _segmentMeters,
              onUndo: _undoLastPoint,
              onClear: _clearRoute,
              theme: Theme.of(context),
              measureEnabled: _measureEnabled,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers for measurement ---
  void _undoLastPoint() {
    if (_routePoints.isEmpty) return;
    setState(() {
      _routePoints.removeLast();
      if (_segmentMeters.isNotEmpty) {
        _segmentMeters.removeLast();
      }
    });
  }

  void _clearRoute() {
    if (_routePoints.isEmpty && _segmentMeters.isEmpty) return;
    setState(() {
      _routePoints.clear();
      _segmentMeters.clear();
    });
  }
}

// --- UI Widgets for measurement ---
class _PointMarker extends StatelessWidget {
  final int index;
  const _PointMarker({required this.index});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.secondaryContainer;
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: fg, width: 2),
          ),
        ),
        // Tiny index label for readability on zoom-in
        Positioned(
          bottom: -10,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }
}

class _DistancePanel extends StatelessWidget {
  final List<double> segmentMeters;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final ThemeData theme;
  final bool measureEnabled;

  const _DistancePanel({
    required this.segmentMeters,
    required this.onUndo,
    required this.onClear,
    required this.theme,
    required this.measureEnabled,
  });

  double get _totalMeters => segmentMeters.fold(0.0, (a, b) => a + b);

  String _fmt(double meters) {
    if (meters < 950) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = theme.colorScheme.surface;
    final onCard = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black26,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: onCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Measure',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onCard,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Undo last point',
                    icon: const Icon(Icons.undo, size: 18),
                    color: onCard,
                    onPressed: onUndo,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Clear route',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: onCard,
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${_fmt(_totalMeters)}',
                style: theme.textTheme.titleSmall?.copyWith(color: onCard),
              ),
              if (segmentMeters.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Tap the map to add points'),
                )
              else ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < segmentMeters.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Segment ${i + 1}: ${_fmt(segmentMeters[i])}',
                            ),
                          ),
                      ],
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
