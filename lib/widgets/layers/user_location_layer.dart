import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Marker layer showing the user's current location as a dot with halo.
class UserLocationLayer extends StatelessWidget {
  const UserLocationLayer({super.key, required this.position});

  final LatLng? position;

  @override
  Widget build(BuildContext context) {
    if (position == null) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        Marker(
          point: position!,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.25),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
