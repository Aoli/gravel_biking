import 'package:flutter/material.dart';

class DrawerFooter extends StatelessWidget {
  final String appVersion;
  final String buildNumber;

  const DrawerFooter({
    super.key,
    required this.appVersion,
    required this.buildNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '© Gravel First 2025',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          Builder(
            builder: (context) {
              final parts = <String>[];
              if (appVersion.isNotEmpty) parts.add('v$appVersion');
              if (buildNumber.isNotEmpty) parts.add('#$buildNumber');
              final label = parts.join(' ');
              if (label.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w300,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
