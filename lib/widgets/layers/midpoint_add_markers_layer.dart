import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Layer that renders midpoint "add" markers between route points when editing.
class MidpointAddMarkersLayer extends StatelessWidget {
  const MidpointAddMarkersLayer({
    super.key,
    required this.routePoints,
    required this.loopClosed,
    required this.onAddBetween,
  });

  final List<LatLng> routePoints;
  final bool loopClosed;
  final void Function(int beforeIndex, int afterIndex, LatLng midpoint)
  onAddBetween;

  @override
  Widget build(BuildContext context) {
    if (routePoints.length < 2) return const SizedBox.shrink();

    final markers = <Marker>[];

    for (int i = 0; i < routePoints.length - 1; i++) {
      final midpoint = LatLng(
        (routePoints[i].latitude + routePoints[i + 1].latitude) / 2,
        (routePoints[i].longitude + routePoints[i + 1].longitude) / 2,
      );
      markers.add(
        Marker(
          point: midpoint,
          width: 16,
          height: 16,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onAddBetween(i, i + 1, midpoint),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSecondary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 10,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ),
      );
    }

    if (loopClosed && routePoints.length >= 3) {
      final midpoint = LatLng(
        (routePoints.last.latitude + routePoints.first.latitude) / 2,
        (routePoints.last.longitude + routePoints.first.longitude) / 2,
      );
      markers.add(
        Marker(
          point: midpoint,
          width: 16,
          height: 16,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onAddBetween(routePoints.length - 1, 0, midpoint),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSecondary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 10,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }
}
