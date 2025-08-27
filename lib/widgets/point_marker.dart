import 'package:flutter/material.dart';

/// Widget for displaying route point markers on the map
class PointMarker extends StatelessWidget {
  final int index;
  final double size;
  final bool isStartPoint;
  final bool isEndPoint;
  final bool measureEnabled;
  final bool isEditing;
  final bool isLoopClosed;

  const PointMarker({
    super.key,
    required this.index,
    this.size = 14.0,
    this.isStartPoint = false,
    this.isEndPoint = false,
    required this.measureEnabled, // Make this required so it's always passed explicitly
    this.isEditing = false,
    this.isLoopClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // When measure mode is OFF, use enhanced visualization for start/end points
    if (!measureEnabled) {
      // For middle points (not start/end), use subtle visualization
      if (!isStartPoint && !isEndPoint) {
        final subtleColor = primaryColor.withValues(alpha: 0.8);
        final subtleSize = size * 0.3; // Make it 30% of the original size

        return Container(
          width: subtleSize,
          height: subtleSize,
          decoration: BoxDecoration(color: subtleColor, shape: BoxShape.circle),
        );
      }

      // For start/end points in view mode, use larger, more visible markers
      return _buildViewModeMarker(context);
    }

    // When measure mode is ON, use full interactive appearance
    // Calculate border width relative to size to maintain visual balance
    final borderWidth = (size / 14.0 * 2.0).clamp(1.0, 3.0);

    // Determine marker color and icon based on point type
    Color markerColor;
    IconData? iconData;

    if (isEditing) {
      markerColor = Colors.red; // Distinct red color for selected point
      iconData = null;
    } else if (isStartPoint && isLoopClosed) {
      // Special styling for start point in closed loop (both start and end)
      markerColor = Colors.orange; // Orange for closed loop start/end
      iconData = Icons.refresh; // Refresh icon indicates loop
    } else if (isStartPoint) {
      markerColor = Colors.green;
      iconData = Icons.play_arrow;
    } else if (isEndPoint) {
      markerColor = Colors.red;
      iconData = Icons.stop;
    } else {
      markerColor = primaryColor;
      iconData = null;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: size / 5,
            offset: Offset(0, size / 14),
          ),
        ],
      ),
      // Add icons for special point types
      child: iconData != null
          ? Icon(iconData, color: Colors.white, size: size * 0.6)
          : null,
    );
  }

  /// Build enhanced markers for view mode (measure mode OFF)
  Widget _buildViewModeMarker(BuildContext context) {
    // Use larger size for better visibility in view mode
    final viewModeSize = size * 1.5; // 50% larger than normal
    final borderWidth = 2.0;

    // Special case: closed loop (start and end are same point)
    if (isStartPoint && isLoopClosed) {
      return _buildClosedLoopMarker(viewModeSize, borderWidth);
    }

    // Regular start/end point markers
    Color markerColor;
    IconData iconData;

    if (isStartPoint) {
      markerColor = Colors.green;
      iconData = Icons.play_arrow;
    } else if (isEndPoint) {
      markerColor = Colors.red;
      iconData = Icons.stop;
    } else {
      // Fallback (shouldn't happen in view mode for middle points)
      markerColor = Theme.of(context).colorScheme.primary;
      iconData = Icons.circle;
    }

    return Container(
      width: viewModeSize,
      height: viewModeSize,
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: viewModeSize / 4,
            offset: Offset(0, viewModeSize / 12),
          ),
        ],
      ),
      child: Icon(iconData, color: Colors.white, size: viewModeSize * 0.55),
    );
  }

  /// Build special pill-shaped marker for closed loops
  Widget _buildClosedLoopMarker(double markerSize, double borderWidth) {
    final pillWidth = markerSize * 1.4; // Make it wider like a pill
    final pillHeight = markerSize;

    return Container(
      width: pillWidth,
      height: pillHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(pillHeight / 2),
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: markerSize / 4,
            offset: Offset(0, markerSize / 12),
          ),
        ],
      ),
      child: Row(
        children: [
          // Green half (start)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(pillHeight / 2),
                  bottomLeft: Radius.circular(pillHeight / 2),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: markerSize * 0.35,
                ),
              ),
            ),
          ),
          // Red half (end)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(pillHeight / 2),
                  bottomRight: Radius.circular(pillHeight / 2),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.stop,
                  color: Colors.white,
                  size: markerSize * 0.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
