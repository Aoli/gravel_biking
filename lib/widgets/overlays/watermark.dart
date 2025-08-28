import 'package:flutter/material.dart';

class VersionWatermark extends StatelessWidget {
  const VersionWatermark({
    super.key,
    required this.appVersion,
    required this.buildNumber,
  });

  final String appVersion;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (appVersion.isNotEmpty) parts.add('v$appVersion');
    if (buildNumber.isNotEmpty) parts.add('#$buildNumber');
    final label = parts.join(' ');
    if (label.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 12,
      left: 12,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
