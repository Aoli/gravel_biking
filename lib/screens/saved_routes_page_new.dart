import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import '../utils/coordinate_utils.dart';
import '../providers/service_providers.dart';
import '../providers/ui_providers.dart';
import '../widgets/save_route_dialog.dart';

/// Visibility filter options for saved routes
enum _VisibilityFilter { all, publicOnly, privateOnly }

/// Sorting options for saved routes
enum _SortOption {
  newest,
  oldest,
  distanceAsc,
  distanceDesc,
  nameAZ,
  nameZA,
  publicFirst,
}

/// Enhanced saved routes management page with local Hive storage
class SavedRoutesPage extends ConsumerStatefulWidget {
  final Function(SavedRoute) onLoadRoute;
  final VoidCallback? onRoutesChanged;

  const SavedRoutesPage({
    super.key,
    required this.onLoadRoute,
    this.onRoutesChanged,
  });

  @override
  ConsumerState<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends ConsumerState<SavedRoutesPage> {
  // UI state variables
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Advanced filtering
  double? _minDistance;
  double? _maxDistance;
  bool _showLoopOnly = false;
  bool _showLinearOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _VisibilityFilter _visibilityFilter = _VisibilityFilter.all;
  _SortOption _sortOption = _SortOption.newest;
  bool _showAdvancedFilters = false;

  // Position-based filtering
  LatLng? _positionFilter;
  double? _proximityKm;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch routes from local storage
    final routesAsyncValue = ref.watch(localSavedRoutesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: routesAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorWidget(theme, error),
        data: (routes) => _buildContent(theme, routes),
      ),
      floatingActionButton: _buildFloatingActionButton(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Text(
        'Sparade Rutter',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      actions: [
        _buildSearchAction(theme),
        _buildFilterAction(theme),
        IconButton(
          onPressed: () {
            // Refresh routes
            ref.invalidate(localSavedRoutesProvider);
          },
          icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
          tooltip: 'Uppdatera',
        ),
      ],
    );
  }

  Widget _buildSearchAction(ThemeData theme) {
    return IconButton(
      onPressed: () => _showSearchDialog(theme),
      icon: Icon(Icons.search, color: theme.colorScheme.onSurface),
      tooltip: 'Sök rutter',
    );
  }

  Widget _buildFilterAction(ThemeData theme) {
    return IconButton(
      onPressed: () =>
          setState(() => _showAdvancedFilters = !_showAdvancedFilters),
      icon: Icon(
        _showAdvancedFilters ? Icons.filter_list : Icons.filter_list_outlined,
        color: theme.colorScheme.onSurface,
      ),
      tooltip: 'Filtrera',
    );
  }

  Widget _buildErrorWidget(ThemeData theme, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Kunde inte ladda rutter',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(localSavedRoutesProvider),
            child: const Text('Försök igen'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, List<SavedRoute> allRoutes) {
    // Apply filters and sorting
    final filteredRoutes = _applyFiltersAndSorting(allRoutes);

    if (allRoutes.isEmpty) {
      return _buildEmptyState(theme, 'Inga rutter sparade än');
    }

    if (filteredRoutes.isEmpty) {
      return _buildEmptyState(theme, 'Inga rutter matchar filtren');
    }

    return Column(
      children: [
        if (_showAdvancedFilters) _buildAdvancedFilters(theme),
        _buildRouteStats(theme, filteredRoutes.length, allRoutes.length),
        Expanded(child: _buildRoutesList(theme, filteredRoutes)),
      ],
    );
  }

  List<SavedRoute> _applyFiltersAndSorting(List<SavedRoute> routes) {
    var filtered = routes.where((route) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = route.name.toLowerCase().contains(query);
        final matchesId = (route.firestoreId ?? '').toLowerCase().contains(
          query,
        );
        if (!matchesName && !matchesId) return false;
      }

      // Distance filter
      if (_minDistance != null && (route.distance ?? 0) < _minDistance!) {
        return false;
      }
      if (_maxDistance != null && (route.distance ?? 0) > _maxDistance!) {
        return false;
      }

      // Loop filter
      if (_showLoopOnly && !route.loopClosed) {
        return false;
      }
      if (_showLinearOnly && route.loopClosed) {
        return false;
      }

      // Date filter
      if (_dateFrom != null && route.savedAt.isBefore(_dateFrom!)) {
        return false;
      }
      if (_dateTo != null &&
          route.savedAt.isAfter(_dateTo!.add(const Duration(days: 1)))) {
        return false;
      }

      // Visibility filter
      switch (_visibilityFilter) {
        case _VisibilityFilter.publicOnly:
          if (!route.isPublic) return false;
        case _VisibilityFilter.privateOnly:
          if (route.isPublic) return false;
        case _VisibilityFilter.all:
          break;
      }

      // Position-based filter
      if (_positionFilter != null && _proximityKm != null) {
        if (route.points.isEmpty) return false;
        final firstPoint = LatLng(
          route.points.first.latitude,
          route.points.first.longitude,
        );
        final distance = CoordinateUtils.calculateDistance(
          _positionFilter!,
          firstPoint,
        );
        if (distance > _proximityKm! * 1000) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    switch (_sortOption) {
      case _SortOption.newest:
        filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      case _SortOption.oldest:
        filtered.sort((a, b) => a.savedAt.compareTo(b.savedAt));
      case _SortOption.distanceAsc:
        filtered.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      case _SortOption.distanceDesc:
        filtered.sort((a, b) => (b.distance ?? 0).compareTo(a.distance ?? 0));
      case _SortOption.nameAZ:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortOption.nameZA:
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case _SortOption.publicFirst:
        filtered.sort((a, b) {
          if (a.isPublic && !b.isPublic) return -1;
          if (!a.isPublic && b.isPublic) return 1;
          return b.savedAt.compareTo(a.savedAt);
        });
    }

    return filtered;
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (message.contains('matchar')) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _clearAllFilters(),
              child: const Text('Rensa filter'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteStats(ThemeData theme, int filteredCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$filteredCount av $totalCount rutter',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          if (_searchQuery.isNotEmpty || _showAdvancedFilters) ...[
            TextButton.icon(
              onPressed: () => _clearAllFilters(),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Rensa'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                textStyle: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutesList(ThemeData theme, List<SavedRoute> routes) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: routes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildRouteCard(theme, routes[index]),
    );
  }

  Widget _buildRouteCard(ThemeData theme, SavedRoute route) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onLoadRoute(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteHeader(theme, route),
              const SizedBox(height: 8),
              _buildRouteInfo(theme, route),
              const SizedBox(height: 8),
              _buildRouteActions(theme, route),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteHeader(ThemeData theme, SavedRoute route) {
    return Row(
      children: [
        Expanded(
          child: Text(
            route.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (route.isPublic)
          Icon(Icons.public, size: 16, color: theme.colorScheme.primary)
        else
          Icon(
            Icons.lock,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        if (route.loopClosed) ...[
          const SizedBox(width: 4),
          Icon(Icons.loop, size: 16, color: theme.colorScheme.secondary),
        ],
      ],
    );
  }

  Widget _buildRouteInfo(ThemeData theme, SavedRoute route) {
    final distanceText = (route.distance ?? 0) >= 1000
        ? '${((route.distance ?? 0) / 1000).toStringAsFixed(1)} km'
        : '${(route.distance ?? 0).round()} m';

    final timeAgo = _getTimeAgoString(route.savedAt);

    return Row(
      children: [
        Icon(
          Icons.straighten,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          distanceText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.access_time,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          timeAgo,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.place,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          '${route.points.length} punkter',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteActions(ThemeData theme, SavedRoute route) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => widget.onLoadRoute(route),
          icon: const Icon(Icons.map, size: 16),
          label: const Text('Ladda'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            textStyle: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _copyRoute(route),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Kopiera'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.secondary,
            textStyle: theme.textTheme.bodySmall,
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) => _handleRouteAction(value, route),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit_name',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Redigera namn'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Radera', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avancerade filter',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildDistanceFilter(theme),
          const SizedBox(height: 16),
          _buildTypeAndVisibilityFilters(theme),
          const SizedBox(height: 16),
          _buildDateFilter(theme),
          const SizedBox(height: 16),
          _buildSortingOptions(theme),
        ],
      ),
    );
  }

  Widget _buildDistanceFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distans (km)',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Min',
                  suffixText: 'km',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minDistance = double.tryParse(value);
                    if (_minDistance != null) {
                      _minDistance = _minDistance! * 1000;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Max',
                  suffixText: 'km',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _maxDistance = double.tryParse(value);
                    if (_maxDistance != null) {
                      _maxDistance = _maxDistance! * 1000;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeAndVisibilityFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Typ och synlighet',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Endast slingor'),
              selected: _showLoopOnly,
              onSelected: (selected) {
                setState(() {
                  _showLoopOnly = selected;
                  if (selected) {
                    _showLinearOnly = false;
                  }
                });
              },
            ),
            FilterChip(
              label: const Text('Endast linjära'),
              selected: _showLinearOnly,
              onSelected: (selected) {
                setState(() {
                  _showLinearOnly = selected;
                  if (selected) {
                    _showLoopOnly = false;
                  }
                });
              },
            ),
            DropdownButton<_VisibilityFilter>(
              value: _visibilityFilter,
              items: const [
                DropdownMenuItem(
                  value: _VisibilityFilter.all,
                  child: Text('Alla rutter'),
                ),
                DropdownMenuItem(
                  value: _VisibilityFilter.publicOnly,
                  child: Text('Endast offentliga'),
                ),
                DropdownMenuItem(
                  value: _VisibilityFilter.privateOnly,
                  child: Text('Endast privata'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _visibilityFilter = value);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datum',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(context, true),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _dateFrom?.toString().split(' ')[0] ?? 'Från datum',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(context, false),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_dateTo?.toString().split(' ')[0] ?? 'Till datum'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortingOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sortera efter',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<_SortOption>(
          value: _sortOption,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: _SortOption.newest,
              child: Text('Nyast först'),
            ),
            DropdownMenuItem(
              value: _SortOption.oldest,
              child: Text('Äldst först'),
            ),
            DropdownMenuItem(
              value: _SortOption.distanceAsc,
              child: Text('Distans (stigande)'),
            ),
            DropdownMenuItem(
              value: _SortOption.distanceDesc,
              child: Text('Distans (fallande)'),
            ),
            DropdownMenuItem(
              value: _SortOption.nameAZ,
              child: Text('Namn (A-Ö)'),
            ),
            DropdownMenuItem(
              value: _SortOption.nameZA,
              child: Text('Namn (Ö-A)'),
            ),
            DropdownMenuItem(
              value: _SortOption.publicFirst,
              child: Text('Offentliga först'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _sortOption = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return FloatingActionButton(
      onPressed: () => _showSaveCurrentRouteDialog(),
      tooltip: 'Spara aktuell rutt',
      child: const Icon(Icons.add),
    );
  }

  // Helper methods
  String _getTimeAgoString(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} dagar sedan';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} timmar sedan';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuter sedan';
    } else {
      return 'Just nu';
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _minDistance = null;
      _maxDistance = null;
      _showLoopOnly = false;
      _showLinearOnly = false;
      _dateFrom = null;
      _dateTo = null;
      _visibilityFilter = _VisibilityFilter.all;
      _sortOption = _SortOption.newest;
      _positionFilter = null;
      _proximityKm = null;
      _showAdvancedFilters = false;
    });
  }

  void _showSearchDialog(ThemeData theme) {
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sök rutter'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Skriv namn eller ID...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) {
            setState(() => _searchQuery = value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = _searchController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Sök'),
          ),
        ],
      ),
    );
  }

  void _copyRoute(SavedRoute originalRoute) async {
    try {
      final routeService = ref.read(routeServiceProvider);

      // Use saveCurrentRoute method with the existing route data
      await routeService.saveCurrentRoute(
        name: '${originalRoute.name} (kopia)',
        routePoints: originalRoute.latLngPoints,
        loopClosed: originalRoute.loopClosed,
        description: originalRoute.description,
      );

      // Refresh the routes list
      ref.invalidate(localSavedRoutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rutt kopierad som "${originalRoute.name} (kopia)"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte kopiera rutt: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleRouteAction(String action, SavedRoute route) {
    switch (action) {
      case 'edit_name':
        _showEditNameDialog(route);
        break;
      case 'delete':
        _showDeleteConfirmation(route);
        break;
    }
  }

  void _showEditNameDialog(SavedRoute route) {
    final controller = TextEditingController(text: route.name);

    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera namn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ruttnamn',
            hintText: 'Ange nytt namn...',
          ),
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != route.name) {
                await _updateRouteName(route, newName);
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRouteName(SavedRoute route, String newName) async {
    try {
      final routeService = ref.read(routeServiceProvider);

      // Create updated route with new name
      final updatedRoute = route.copyWith(name: newName);

      // Use updateRoute method from RouteService
      await routeService.updateRoute(route, updatedRoute);

      // Refresh the routes list
      ref.invalidate(localSavedRoutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ruttnamn ändrat till "$newName"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte uppdatera namn: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(SavedRoute route) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radera rutt'),
        content: Text(
          'Är du säker på att du vill radera "${route.name}"?\n\nDenna åtgärd kan inte ångras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Radera'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _deleteRoute(route);
      }
    });
  }

  Future<void> _deleteRoute(SavedRoute route) async {
    try {
      final routeService = ref.read(routeServiceProvider);
      await routeService.deleteRouteObject(route);

      // Refresh the routes list
      ref.invalidate(localSavedRoutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rutt "${route.name}" raderad'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => _restoreRoute(route),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte radera rutt: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreRoute(SavedRoute route) async {
    try {
      final routeService = ref.read(routeServiceProvider);

      // Save the route back using saveCurrentRoute
      await routeService.saveCurrentRoute(
        name: route.name,
        routePoints: route.latLngPoints,
        loopClosed: route.loopClosed,
        description: route.description,
      );

      // Refresh the routes list
      ref.invalidate(localSavedRoutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rutt "${route.name}" återställd'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte återställa rutt: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? _dateFrom ?? DateTime.now()
          : _dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isFromDate) {
          _dateFrom = date;
        } else {
          _dateTo = date;
        }
      });
    }
  }

  void _showSaveCurrentRouteDialog() async {
    // Read current measurement state
    final currentPoints = ref.read(routePointsProvider);
    final currentLoopClosed = ref.read(loopClosedProvider);

    // Prevent saving when there's no route
    if (currentPoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      }
      return;
    }

    final routesAsyncValue = ref.read(localSavedRoutesProvider);
    final routeCount = routesAsyncValue.when(
      data: (routes) => routes.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    await SaveRouteDialog.show(
      context,
      onSave: (name, isPublic) async {
        final routeService = ref.read(routeServiceProvider);
        // For simple local storage, we need to get current route from somewhere
        // This needs to be connected to the main app's current route state
        try {
          // This is a placeholder - the actual implementation would need
          // access to the current route being measured
          await routeService.saveCurrentRoute(
            name: name,
            routePoints: currentPoints,
            loopClosed: currentLoopClosed,
            description: '',
          );

          ref.invalidate(localSavedRoutesProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rutt "$name" sparad'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kunde inte spara rutt: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      savedRoutesCount: routeCount,
      initialName: '', // initialName parameter pass-through
      maxSavedRoutes: 50, // Default max
      isAuthenticated: false, // Local storage doesn't require auth
    );

    // Refresh routes after dialog closes
    ref.invalidate(localSavedRoutesProvider);
    if (widget.onRoutesChanged != null) {
      widget.onRoutesChanged!();
    }
  }
}
