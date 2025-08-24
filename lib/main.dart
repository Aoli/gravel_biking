import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xml/xml.dart' as xml;

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
  LatLng? _myPosition;
  Timer? _moveDebounce;
  LatLngBounds? _lastFetchedBounds;
  LatLngBounds? _lastEventBounds;

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
    // Initial fetch for a sensible area (Stockholm bbox)
    _fetchGravelForBounds(
      LatLngBounds(const LatLng(59.3, 18.0), const LatLng(59.4, 18.1)),
    );
  }

  void _onMapEvent(MapEvent event) {
    // Debounce on any map movement/zoom/rotate event
    _lastEventBounds = event.camera.visibleBounds;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gravel Streets Map'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            child: IconButton(
              tooltip: 'Locate me',
                icon: Icon(
                  Icons.my_location,
                  color: (Theme.of(context).brightness == Brightness.dark)
                      ? Colors.white
                      : Colors.black,
                ),
              onPressed: _locateMe,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _measureEnabled ? Colors.green : Colors.red,
            ),
            child: IconButton(
              tooltip: _measureEnabled
                  ? 'Disable measure mode'
                  : 'Enable measure mode',
              icon: const Icon(Icons.straighten, color: Colors.white),
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
                          'Menu',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Import / Export'),
                      leading: const Icon(Icons.folder_open),
                    ),
                    ExpansionTile(
                      leading: const Icon(Icons.map),
                      title: const Text('GeoJSON'),
                      initiallyExpanded: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.file_open),
                          title: const Text('Import GeoJSON'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _importGeoJsonRoute();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.save_alt),
                          title: const Text('Export GeoJSON'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _exportGeoJsonRoute();
                          },
                        ),
                      ],
                    ),
                    ExpansionTile(
                      leading: const Icon(Icons.route),
                      title: const Text('GPX'),
                      initiallyExpanded: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.file_open),
                          title: const Text('Import GPX'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _importGpxRoute();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.file_download),
                          title: const Text('Export GPX'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _exportGpxRoute();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Close'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '© Christian Ericsson 2025',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
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
          const SnackBar(content: Text('Location services are disabled')),
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
          const SnackBar(content: Text('Location permission denied')),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    }
  }

  Future<void> _exportGeoJsonRoute() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No route to export')));
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
        const SnackBar(content: Text('Route exported as GeoJSON')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
        SnackBar(content: Text('Imported ${_routePoints.length} points')),
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
      ).showSnackBar(const SnackBar(content: Text('No route to export')));
      return;
    }
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', 'Gravel Biking');
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
      ).showSnackBar(const SnackBar(content: Text('Route exported as GPX')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
          const SnackBar(content: Text('No track points found in GPX')),
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
          content: Text('Imported ${_routePoints.length} points from GPX'),
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
                  child: Text(
                    'Tap the map to add points in edit mode (green edit button)',
                  ),
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

// (Import/Export UI moved into Drawer)
