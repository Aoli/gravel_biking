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
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    // When measure mode is OFF, use subtle visualization
    if (!measureEnabled) {
      // Subtle point markers - much smaller, similar color, no borders
      final subtleColor = primaryColor.withValues(alpha: 0.8);
      final subtleSize = size * 0.3; // Make it 30% of the original size

      return Container(
        width: subtleSize,
        height: subtleSize,
        decoration: BoxDecoration(color: subtleColor, shape: BoxShape.circle),
      );
    }

    // When measure mode is ON, use full interactive appearance
    // Calculate border width relative to size to maintain visual balance
    final borderWidth = (size / 14.0 * 2.0).clamp(1.0, 3.0);

    // Determine marker color and icon based on point type
    Color markerColor;
    IconData? iconData;

    if (isEditing) {
      markerColor = tertiaryColor;
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
}
