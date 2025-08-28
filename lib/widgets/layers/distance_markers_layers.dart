import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Combined distance markers layer with both orange dots and distance labels
class DistanceMarkersLayer extends StatelessWidget {
  const DistanceMarkersLayer({
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
          label = '${(distanceKm * 1000).toInt()}m';
        } else if (distanceKm == distanceKm.toInt()) {
          label = distanceKm.toInt().toString();
        } else {
          label = distanceKm.toStringAsFixed(1);
        }

        return Marker(
          point: point,
          width: 80.0, // Increased width to accommodate larger touch area
          height: 40.0, // Increased height for larger touch area
          alignment: Alignment
              .centerLeft, // Align to center-left so dot is centered on route
          child: GestureDetector(
            onTap: () => onTap(index, distanceKm),
            child: Container(
              width: 80.0,
              height: 40.0,
              // Transparent background to expand touch area
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Orange dot positioned precisely on the polyline
                  Positioned(
                    left:
                        0, // Position dot at the exact left edge (on polyline)
                    top: 15.0, // Center vertically in 40px height container
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
                  // Distance label positioned to the right of the dot
                  Positioned(
                    left: 16.0, // Position label 16px from left (dot + spacing)
                    top: 8.0, // Center the label vertically
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.deepOrange.withValues(alpha: 0.9),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.0, // Tight line height
                        ),
                      ),
                    ),
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
          width: 30.0, // Increased touch area width
          height: 30.0, // Increased touch area height
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onTap(index, distanceKm),
            child: Container(
              width: 30.0,
              height: 30.0,
              // Transparent background to expand touch area
              color: Colors.transparent,
              child: Center(
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
          width: 48, // Increased touch area width
          height: 40, // Increased touch area height
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => onTap(index, distanceKm),
            child: Container(
              width: 48,
              height: 40,
              // Transparent background to expand touch area
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 32,
                  height: 24,
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
            ),
          ),
        );
      }).toList(),
    );
  }
}
