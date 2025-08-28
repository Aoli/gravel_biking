import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../point_marker.dart';

typedef PointTap = void Function(int index);

/// Layer that renders route point markers with view/measure/edit modes.
class RoutePointsLayer extends StatelessWidget {
  const RoutePointsLayer({
    super.key,
    required this.points,
    required this.measureEnabled,
    required this.editModeEnabled,
    required this.lastZoom,
    required this.isLoopClosed,
    required this.isEditingIndex,
    required this.onTapPoint,
    required this.onLongPressPoint,
  });

  final List<LatLng> points;
  final bool measureEnabled;
  final bool editModeEnabled;
  final double? lastZoom;
  final bool isLoopClosed;
  final int? isEditingIndex;
  final PointTap onTapPoint;
  final PointTap onLongPressPoint;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (int i = 0; i < points.length; i++)
          ..._buildMarkerForIndex(context, i),
      ],
    );
  }

  List<Marker> _buildMarkerForIndex(BuildContext context, int i) {
    final markers = <Marker>[];
    final isStartPoint = i == 0; // Always treat first point as start point
    final isEndPoint = i == points.length - 1 && points.length > 1;
    final isStartOrEnd = isStartPoint || isEndPoint;

    // In non-measurement mode, only show start/end points (when enough points)
    // Exception: always show the first point, even if it's the only point
    if (!measureEnabled && !isStartOrEnd && points.length > 2) {
      return markers; // empty
    }

    final currentZoom = lastZoom ?? 12.0;
    if (points.length > 1000 && currentZoom < 13.0) {
      if (!isStartOrEnd && i % 10 != 0) return markers;
    } else if (points.length > 500 && currentZoom < 11.0) {
      if (!isStartOrEnd && i % 20 != 0) return markers;
    }

    final baseSize = editModeEnabled ? 16.0 : 2.0;
    final markerSize = measureEnabled ? baseSize : baseSize * 0.8;

    markers.add(
      Marker(
        point: points[i],
        width: markerSize,
        height: markerSize,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => onTapPoint(i),
          onLongPress: () => onLongPressPoint(i),
          child: editModeEnabled
              ? PointMarker(
                  key: ValueKey(
                    'point_${i}_measure_${measureEnabled}_edit_${isEditingIndex}_loop_$isLoopClosed',
                  ),
                  index: i,
                  size: 16.0,
                  isStartPoint: isStartPoint,
                  isEndPoint: isEndPoint,
                  measureEnabled: measureEnabled,
                  isEditing: isEditingIndex == i,
                  isLoopClosed: isLoopClosed,
                )
              : (!measureEnabled && isStartOrEnd)
              ? PointMarker(
                  key: ValueKey('view_point_${i}_loop_$isLoopClosed'),
                  index: i,
                  size: 18.0,
                  isStartPoint: isStartPoint,
                  isEndPoint: isEndPoint,
                  measureEnabled: false,
                  isEditing: false,
                  isLoopClosed: isLoopClosed,
                )
              : measureEnabled &&
                    isStartPoint // Show green start marker in measure mode
              ? PointMarker(
                  key: ValueKey('measure_start_point_${i}_loop_$isLoopClosed'),
                  index: i,
                  size: markerSize,
                  isStartPoint: isStartPoint,
                  isEndPoint: isEndPoint,
                  measureEnabled: measureEnabled,
                  isEditing: false,
                  isLoopClosed: isLoopClosed,
                )
              : Container(
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
      ),
    );

    return markers;
  }
}
