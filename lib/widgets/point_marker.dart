import 'package:flutter/material.dart';

/// Widget for displaying route point markers on the map
class PointMarker extends StatelessWidget {
  final int index;
  final bool isEditing;
  final double size;
  final bool isStartPoint;
  final bool isEndPoint;
  final bool isLoopClosed;

  const PointMarker({
    super.key,
    required this.index,
    this.isEditing = false,
    this.size = 14.0,
    this.isStartPoint = false,
    this.isEndPoint = false,
    this.isLoopClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

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
      markerColor = Colors.orange;  // Orange for closed loop start/end
      iconData = Icons.refresh;     // Refresh icon indicates loop
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
      child: iconData != null ? Icon(
        iconData,
        color: Colors.white,
        size: size * 0.6,
      ) : null,
    );
  }
}
