import 'package:flutter/material.dart';
import '../../widgets/distance_panel.dart';

class BottomControlsPanel extends StatelessWidget {
  const BottomControlsPanel({
    super.key,
    required this.segmentMeters,
    required this.onUndo,
    required this.onSave,
    required this.onClear,
    required this.onEditModeChanged,
    required this.measureEnabled,
    required this.loopClosed,
    required this.canToggleLoop,
    required this.onToggleLoop,
    required this.editModeEnabled,
    required this.showDistanceMarkers,
    required this.onDistanceMarkersToggled,
    required this.distanceInterval,
    required this.canUndo,
    required this.onToggleMeasure,
  });

  final List<double> segmentMeters;
  final VoidCallback onUndo;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final ValueChanged<bool> onEditModeChanged;
  final bool measureEnabled;
  final bool loopClosed;
  final bool canToggleLoop;
  final VoidCallback onToggleLoop;
  final bool editModeEnabled;
  final bool showDistanceMarkers;
  final ValueChanged<bool> onDistanceMarkersToggled;
  final double distanceInterval;
  final bool canUndo;
  final VoidCallback onToggleMeasure;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DistancePanel(
              segmentMeters: segmentMeters,
              onUndo: onUndo,
              onSave: onSave,
              onClear: onClear,
              onEditModeChanged: onEditModeChanged,
              theme: Theme.of(context),
              measureEnabled: measureEnabled,
              loopClosed: loopClosed,
              canToggleLoop: canToggleLoop,
              onToggleLoop: onToggleLoop,
              editModeEnabled: editModeEnabled,
              showDistanceMarkers: showDistanceMarkers,
              onDistanceMarkersToggled: onDistanceMarkersToggled,
              distanceInterval: distanceInterval,
              canUndo: canUndo,
              onToggleMeasure: onToggleMeasure,
            ),
          ],
        ),
      ),
    );
  }
}
