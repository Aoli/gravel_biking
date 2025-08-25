import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import '../services/route_service.dart';
import '../utils/coordinate_utils.dart';

/// Enhanced saved routes management page with search and organization
class SavedRoutesPage extends StatefulWidget {
  final RouteService routeService;
  final Function(SavedRoute)
  onLoadRoute; // Changed to pass the full SavedRoute object
  final VoidCallback? onRoutesChanged; // Callback for when routes are modified

  const SavedRoutesPage({
    super.key,
    required this.routeService,
    required this.onLoadRoute,
    this.onRoutesChanged,
  });

  @override
  State<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends State<SavedRoutesPage> {
  List<SavedRoute> _routes = [];
  List<SavedRoute> _filteredRoutes = [];
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Advanced filtering
  double? _minDistance;
  double? _maxDistance;
  bool _showLoopOnly = false;
  bool _showLinearOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  LatLng? _currentPosition;
  double? _maxDistanceFromPosition;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      final routes = await widget.routeService.loadSavedRoutes();
      setState(() {
        _routes = routes;
        _filteredRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fel vid inläsning av rutter: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text;
    setState(() {
      _searchQuery = query;
      _filteredRoutes = _routes.where((route) {
        // Text search
        if (query.isNotEmpty) {
          final searchLower = query.toLowerCase();
          if (!route.name.toLowerCase().contains(searchLower) &&
              !(route.description?.toLowerCase().contains(searchLower) ??
                  false)) {
            return false;
          }
        }

        // Distance range filter
        if (_minDistance != null && (route.distance ?? 0) < _minDistance!) {
          return false;
        }
        if (_maxDistance != null && (route.distance ?? 0) > _maxDistance!) {
          return false;
        }

        // Loop type filter
        if (_showLoopOnly && !route.loopClosed) return false;
        if (_showLinearOnly && route.loopClosed) return false;

        // Date range filter
        if (_dateFrom != null && route.savedAt.isBefore(_dateFrom!)) {
          return false;
        }
        if (_dateTo != null &&
            route.savedAt.isAfter(_dateTo!.add(const Duration(days: 1)))) {
          return false;
        }

        // Distance from current position filter
        if (_maxDistanceFromPosition != null && _currentPosition != null) {
          final routeCenter = _calculateRouteCenter(route);
          final distance = _calculateDistance(_currentPosition!, routeCenter);
          if (distance > _maxDistanceFromPosition!) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  LatLng _calculateRouteCenter(SavedRoute route) {
    final points = route.latLngPoints;
    if (points.isEmpty) return const LatLng(0, 0);

    double lat = 0, lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = from.latitude * (math.pi / 180);
    final double lat2Rad = to.latitude * (math.pi / 180);
    final double deltaLatRad = (to.latitude - from.latitude) * (math.pi / 180);
    final double deltaLngRad =
        (to.longitude - from.longitude) * (math.pi / 180);

    final double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c; // Distance in meters
  }

  Future<void> _editRouteName(SavedRoute route) async {
    final TextEditingController controller = TextEditingController(
      text: route.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ändra ruttnamn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ruttnamn',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != route.name) {
      try {
        // Create updated route with new name
        final updatedRoute = SavedRoute.fromLatLng(
          name: result,
          latLngPoints: route.latLngPoints,
          loopClosed: route.loopClosed,
          savedAt: route.savedAt,
          description: route.description,
          distance: route.distance,
        );

        // Update route (delete old, add new)
        await widget.routeService.updateRoute(route, updatedRoute);
        await _loadRoutes();

        // Notify parent widget that routes have changed
        widget.onRoutesChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ruttnamn ändrat till "$result"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fel vid namnändring: $e')));
        }
      }
    }
  }

  void _showAdvancedFiltersDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AdvancedFiltersDialog(
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        showLoopOnly: _showLoopOnly,
        showLinearOnly: _showLinearOnly,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        maxDistanceFromPosition: _maxDistanceFromPosition,
        currentPosition: _currentPosition,
      ),
    );

    if (result != null) {
      setState(() {
        _minDistance = result['minDistance'];
        _maxDistance = result['maxDistance'];
        _showLoopOnly = result['showLoopOnly'] ?? false;
        _showLinearOnly = result['showLinearOnly'] ?? false;
        _dateFrom = result['dateFrom'];
        _dateTo = result['dateTo'];
        _maxDistanceFromPosition = result['maxDistanceFromPosition'];
      });
      _applyFilters();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _minDistance = null;
      _maxDistance = null;
      _showLoopOnly = false;
      _showLinearOnly = false;
      _dateFrom = null;
      _dateTo = null;
      _maxDistanceFromPosition = null;
    });
    _applyFilters();
  }

  bool _hasActiveFilters() {
    return _minDistance != null ||
        _maxDistance != null ||
        _showLoopOnly ||
        _showLinearOnly ||
        _dateFrom != null ||
        _dateTo != null ||
        _maxDistanceFromPosition != null;
  }

  String _getFilterSummary() {
    final List<String> filters = [];

    if (_minDistance != null || _maxDistance != null) {
      if (_minDistance != null && _maxDistance != null) {
        filters.add(
          '${CoordinateUtils.formatDistance(_minDistance!)} - ${CoordinateUtils.formatDistance(_maxDistance!)}',
        );
      } else if (_minDistance != null) {
        filters.add('Min ${CoordinateUtils.formatDistance(_minDistance!)}');
      } else {
        filters.add('Max ${CoordinateUtils.formatDistance(_maxDistance!)}');
      }
    }

    if (_showLoopOnly) filters.add('Endast slingor');
    if (_showLinearOnly) filters.add('Endast linjära');
    if (_dateFrom != null || _dateTo != null) filters.add('Datum');
    if (_maxDistanceFromPosition != null) filters.add('Närhet');

    return filters.join(', ');
  }

  Future<void> _deleteRoute(SavedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort rutt'),
        content: Text('Är du säker på att du vill ta bort "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.routeService.deleteRouteObject(route);
        await _loadRoutes();

        // Notify parent widget that routes have changed
        widget.onRoutesChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Rutt borttagen')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fel vid borttagning: $e')));
        }
      }
    }
  }

  void _loadRoute(SavedRoute route) {
    widget.onLoadRoute(
      route,
    ); // Pass the full SavedRoute object instead of just points
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Laddade rutt "${route.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sparade rutter'),
            if (_routes.isNotEmpty)
              Text(
                '${_filteredRoutes.length} av ${_routes.length} rutter',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Sök rutter...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
          ),

          // Filter buttons
          if (_routes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (_hasActiveFilters())
                          ActionChip(
                            avatar: const Icon(Icons.filter_list, size: 18),
                            label: Text(_getFilterSummary()),
                            onPressed: _showAdvancedFiltersDialog,
                            backgroundColor: theme.colorScheme.primaryContainer,
                          )
                        else
                          ActionChip(
                            avatar: const Icon(Icons.tune, size: 18),
                            label: const Text('Filter'),
                            onPressed: _showAdvancedFiltersDialog,
                          ),
                        if (_hasActiveFilters())
                          ActionChip(
                            avatar: const Icon(Icons.clear, size: 18),
                            label: const Text('Rensa'),
                            onPressed: _clearAllFilters,
                            backgroundColor: theme.colorScheme.errorContainer,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Routes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRoutes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.route,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Inga rutter hittades för "$_searchQuery"'
                              : 'Inga sparade rutter ännu',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRoutes,
                    child: ListView.builder(
                      itemCount: _filteredRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _filteredRoutes[index];
                        return _RouteCard(
                          route: route,
                          onLoad: () => _loadRoute(route),
                          onDelete: () => _deleteRoute(route),
                          onEdit: () => _editRouteName(route),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final SavedRoute route;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RouteCard({
    required this.route,
    required this.onLoad,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = route.distance != null
        ? CoordinateUtils.formatDistance(route.distance!)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            route.loopClosed ? Icons.loop : Icons.route,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          route.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (route.description?.isNotEmpty == true) ...[
              Text(route.description!),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(route.savedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.straighten,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'load':
                onLoad();
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'load',
              child: Row(
                children: [
                  Icon(Icons.map),
                  SizedBox(width: 8),
                  Text('Ladda rutt'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Ändra namn'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Ta bort', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: onLoad,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Idag ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Igår';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${date.day}/${date.month} ${date.year}';
    }
  }
}

/// Advanced filters dialog for filtering saved routes
class _AdvancedFiltersDialog extends StatefulWidget {
  final double? minDistance;
  final double? maxDistance;
  final bool showLoopOnly;
  final bool showLinearOnly;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxDistanceFromPosition;
  final LatLng? currentPosition;

  const _AdvancedFiltersDialog({
    this.minDistance,
    this.maxDistance,
    this.showLoopOnly = false,
    this.showLinearOnly = false,
    this.dateFrom,
    this.dateTo,
    this.maxDistanceFromPosition,
    this.currentPosition,
  });

  @override
  State<_AdvancedFiltersDialog> createState() => _AdvancedFiltersDialogState();
}

class _AdvancedFiltersDialogState extends State<_AdvancedFiltersDialog> {
  late double? _minDistance = widget.minDistance;
  late double? _maxDistance = widget.maxDistance;
  late bool _showLoopOnly = widget.showLoopOnly;
  late bool _showLinearOnly = widget.showLinearOnly;
  late DateTime? _dateFrom = widget.dateFrom;
  late DateTime? _dateTo = widget.dateTo;
  late final double? _maxDistanceFromPosition = widget.maxDistanceFromPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Avancerade filter'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Distance range filter
              Text('Ruttlängd', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Min distans (km)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _minDistance != null
                            ? (_minDistance! / 1000).toStringAsFixed(1)
                            : '',
                      ),
                      onChanged: (value) {
                        final km = double.tryParse(value);
                        _minDistance = km != null ? km * 1000 : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Max distans (km)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _maxDistance != null
                            ? (_maxDistance! / 1000).toStringAsFixed(1)
                            : '',
                      ),
                      onChanged: (value) {
                        final km = double.tryParse(value);
                        _maxDistance = km != null ? km * 1000 : null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text('Rutttyp', style: theme.textTheme.titleMedium),
              CheckboxListTile(
                title: const Text('Endast slutna slingor'),
                value: _showLoopOnly,
                onChanged: (value) => setState(() {
                  _showLoopOnly = value ?? false;
                  if (_showLoopOnly) _showLinearOnly = false;
                }),
              ),
              CheckboxListTile(
                title: const Text('Endast linjära rutter'),
                value: _showLinearOnly,
                onChanged: (value) => setState(() {
                  _showLinearOnly = value ?? false;
                  if (_showLinearOnly) _showLoopOnly = false;
                }),
              ),

              const SizedBox(height: 16),
              Text('Datum', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _dateFrom ??
                              DateTime.now().subtract(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _dateFrom = date);
                        }
                      },
                      child: Text(
                        _dateFrom != null
                            ? 'Från: ${_dateFrom!.day}/${_dateFrom!.month}'
                            : 'Från datum',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dateTo ?? DateTime.now(),
                          firstDate: _dateFrom ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _dateTo = date);
                        }
                      },
                      child: Text(
                        _dateTo != null
                            ? 'Till: ${_dateTo!.day}/${_dateTo!.month}'
                            : 'Till datum',
                      ),
                    ),
                  ),
                ],
              ),

              if (_dateFrom != null || _dateTo != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _dateFrom = null;
                        _dateTo = null;
                      }),
                      child: const Text('Rensa datum'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'minDistance': _minDistance,
              'maxDistance': _maxDistance,
              'showLoopOnly': _showLoopOnly,
              'showLinearOnly': _showLinearOnly,
              'dateFrom': _dateFrom,
              'dateTo': _dateTo,
              'maxDistanceFromPosition': _maxDistanceFromPosition,
            });
          },
          child: const Text('Tillämpa'),
        ),
      ],
    );
  }
}
