import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/nvdb_service.dart';

/// Widget that displays NVDB gravel roads as polylines on the map
class NvdbGravelLayer extends StatelessWidget {
  final List<NvdbRoadSegment> gravelRoads;
  final bool visible;

  const NvdbGravelLayer({
    super.key,
    required this.gravelRoads,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || gravelRoads.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return PolylineLayer(
      polylines: gravelRoads.map((segment) {
        return Polyline(
          points: segment.points,
          strokeWidth: 3.0,
          color: _getColorForSurfaceType(segment.surfaceType, colorScheme),
          borderStrokeWidth: 1.0,
          borderColor: Colors.white.withValues(alpha: 0.8),
          useStrokeWidthInMeter: false,
        );
      }).toList(),
    );
  }

  /// Get color for different surface types
  Color _getColorForSurfaceType(String surfaceType, ColorScheme colorScheme) {
    // Different colors for different gravel surface types
    switch (surfaceType.toLowerCase()) {
      case 'grus':
        return Colors.brown.shade600;
      case 'makadam':
        return Colors.grey.shade700;
      case 'sten':
        return Colors.blueGrey.shade600;
      case 'sand':
        return Colors.yellow.shade700;
      case 'jord':
        return Colors.brown.shade800;
      case 'naturmaterial':
        return Colors.green.shade700;
      default:
        return colorScheme.tertiary; // Default gravel color
    }
  }
}

/// Widget that shows NVDB loading indicator
class NvdbLoadingIndicator extends StatelessWidget {
  final bool isLoading;

  const NvdbLoadingIndicator({
    super.key,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
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
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Laddar NVDB...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that shows NVDB statistics
class NvdbInfoCard extends StatelessWidget {
  final List<NvdbRoadSegment> gravelRoads;
  final bool visible;

  const NvdbInfoCard({
    super.key,
    required this.gravelRoads,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || gravelRoads.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Calculate statistics
    final surfaceTypes = <String, int>{};
    for (final segment in gravelRoads) {
      surfaceTypes[segment.surfaceType] = 
          (surfaceTypes[segment.surfaceType] ?? 0) + 1;
    }

    return Positioned(
      bottom: 100,
      right: 16,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.traffic,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'NVDB Grusvägar',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${gravelRoads.length} segment${gravelRoads.length != 1 ? '' : ''}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (surfaceTypes.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...surfaceTypes.entries.take(3).map((entry) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getColorForSurfaceType(entry.key, colorScheme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColorForSurfaceType(String surfaceType, ColorScheme colorScheme) {
    switch (surfaceType.toLowerCase()) {
      case 'grus':
        return Colors.brown.shade600;
      case 'makadam':
        return Colors.grey.shade700;
      case 'sten':
        return Colors.blueGrey.shade600;
      case 'sand':
        return Colors.yellow.shade700;
      case 'jord':
        return Colors.brown.shade800;
      case 'naturmaterial':
        return Colors.green.shade700;
      default:
        return colorScheme.tertiary;
    }
  }
}
