import 'package:flutter/material.dart';
import '../models/saved_route.dart';

enum DuplicateRouteAction { overwrite, createNew, cancel }

class DuplicateRouteDialog extends StatelessWidget {
  const DuplicateRouteDialog({
    super.key,
    required this.routeName,
    required this.existingRoute,
  });

  final String routeName;
  final SavedRoute existingRoute;

  static Future<DuplicateRouteAction?> show(
    BuildContext context, {
    required String routeName,
    required SavedRoute existingRoute,
  }) {
    return showDialog<DuplicateRouteAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DuplicateRouteDialog(
        routeName: routeName,
        existingRoute: existingRoute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Format distance
    String distanceText = 'Okänt avstånd';
    if (existingRoute.distance != null) {
      if (existingRoute.distance! >= 1000) {
        distanceText =
            '${(existingRoute.distance! / 1000).toStringAsFixed(1)} km';
      } else {
        distanceText = '${existingRoute.distance!.round()} m';
      }
    }

    // Format date
    final dateText =
        '${existingRoute.savedAt.day}/${existingRoute.savedAt.month} ${existingRoute.savedAt.year}';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Rutt med samma namn finns')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En rutt med namnet "$routeName" finns redan:',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          routeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(distanceText, style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Icon(
                        existingRoute.loopClosed ? Icons.sync : Icons.timeline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        existingRoute.loopClosed ? 'Slinga' : 'Linje',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sparad $dateText',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      if (existingRoute.isPublic)
                        Row(
                          children: [
                            Icon(
                              Icons.public,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Offentlig',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.lock,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Privat',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vad vill du göra?',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateRouteAction.cancel),
          child: const Text('Avbryt'),
        ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateRouteAction.createNew),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Skapa ny rutt'),
        ),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateRouteAction.overwrite),
          icon: const Icon(Icons.update),
          label: const Text('Skriv över'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
