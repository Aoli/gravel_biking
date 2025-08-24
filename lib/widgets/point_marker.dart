import 'package:flutter/material.dart';

/// Widget for displaying route point markers on the map
class PointMarker extends StatelessWidget {
  final int index;
  final bool isEditing;

  const PointMarker({super.key, required this.index, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isEditing ? tertiaryColor : primaryColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
