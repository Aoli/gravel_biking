import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel Streets',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
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
  bool isLoading = true;

  // Measurement
  final Distance _distance = const Distance();
  final List<LatLng> _routePoints = [];
  final List<double> _segmentMeters = [];
  bool _measureEnabled = false;
  bool _loopClosed = false;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _fetchGravelStreets();
  }

  Future<void> _fetchGravelStreets() async {
    const url = 'https://overpass-api.de/api/interpreter';
    const query = r'''
      [out:json];
      way["highway"~"^(residential|service|track|unclassified|road)$"]["surface"="gravel"](59.3, 18.0, 59.4, 18.1);
      out geom;
    ''';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
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
              initialZoom: 12,
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
              PolylineLayer(polylines: gravelPolylines),
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
              MarkerLayer(
                markers: [
                  for (int i = 0; i < _routePoints.length; i++)
                    Marker(
                      point: _routePoints[i],
                      width: 26,
                      height: 26,
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
          Positioned(
            right: 12,
            bottom: 12,
            child: _DistancePanel(
              segmentMeters: _segmentMeters,
              onUndo: _undoLastPoint,
              onClear: _clearRoute,
              theme: Theme.of(context),
              measureEnabled: _measureEnabled,
              loopClosed: _loopClosed,
              canToggleLoop: _routePoints.length >= 3,
              onToggleLoop: _toggleLoop,
              editingIndex: _editingIndex,
              onCancelEdit: () => setState(() => _editingIndex = null),
            ),
          ),
        ],
      ),
    );
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
}

class _PointMarker extends StatelessWidget {
  final int index;
  final bool isEditing;
  const _PointMarker({required this.index, this.isEditing = false});
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.secondaryContainer;
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isEditing
                ? Theme.of(context).colorScheme.tertiaryContainer
                : bg,
            shape: BoxShape.circle,
            border: Border.all(color: fg, width: 2),
          ),
        ),
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
  final bool loopClosed;
  final bool canToggleLoop;
  final VoidCallback onToggleLoop;
  final int? editingIndex;
  final VoidCallback onCancelEdit;

  const _DistancePanel({
    required this.segmentMeters,
    required this.onUndo,
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
              if (canToggleLoop) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: onCard,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onToggleLoop,
                    icon: Icon(
                      loopClosed ? Icons.link_off : Icons.link,
                      size: 16,
                      color: onCard,
                    ),
                    label: Text(loopClosed ? 'Open loop' : 'Close loop'),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              if (editingIndex != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Editing point #${editingIndex! + 1} — tap map to move',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onCard,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel edit',
                        icon: const Icon(Icons.close, size: 16),
                        color: onCard,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onCancelEdit,
                      ),
                    ],
                  ),
                ),
              ],
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
                        for (
                          int i = 0;
                          i < segmentMeters.length - (loopClosed ? 1 : 0);
                          i++
                        )
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Segment ${i + 1}: ${_fmt(segmentMeters[i])}',
                            ),
                          ),
                        if (loopClosed && segmentMeters.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Loop segment: ${_fmt(segmentMeters.last)}',
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
