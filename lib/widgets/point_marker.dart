import 'package:flutter/material.dart';

/// Widget for displaying route point markers on the map
class PointMarker extends StatelessWidget {
  final int index;
  final bool isEditing;
  final double size;

  const PointMarker({
    super.key,
    required this.index,
    this.isEditing = false,
    this.size = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    // Calculate border width relative to size to maintain visual balance
    final borderWidth = (size / 14.0 * 2.0).clamp(1.0, 3.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isEditing ? tertiaryColor : primaryColor,
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
    );
  }
}
