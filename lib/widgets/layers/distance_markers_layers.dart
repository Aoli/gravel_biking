import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Orange dot distance markers layer (when text markers are disabled)
class DistanceDotsLayer extends StatelessWidget {
  const DistanceDotsLayer({
    super.key,
    required this.markers,
    required this.intervalMeters,
    required this.onTap,
  });

  final List<LatLng> markers;
  final double intervalMeters;
  final void Function(int index, double distanceKm) onTap;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: markers.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        final distanceKm = ((index + 1) * intervalMeters) / 1000.0;

        return Marker(
          point: point,
          width: 10.0,
          height: 10.0,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onTap(index, distanceKm),
            child: Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepOrange,
                border: Border.all(color: Colors.white, width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Text distance markers layer (when enabled)
class DistanceTextLayer extends StatelessWidget {
  const DistanceTextLayer({
    super.key,
    required this.markers,
    required this.intervalMeters,
    required this.onTap,
  });

  final List<LatLng> markers;
  final double intervalMeters;
  final void Function(int index, double distanceKm) onTap;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: markers.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        final distanceKm = ((index + 1) * intervalMeters) / 1000.0;

        String label;
        if (distanceKm < 1) {
          label = '${(distanceKm * 1000).toInt()}m'.replaceAll('000m', 'k');
        } else if (distanceKm == distanceKm.toInt()) {
          label = '${distanceKm.toInt()}k';
        } else {
          label = '${distanceKm}k';
        }

        return Marker(
          point: point,
          width: 32,
          height: 24,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onTap(index, distanceKm),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.orange,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
