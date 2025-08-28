import 'package:flutter/material.dart';

/// Top AppBar for Gravel First with locate, measure toggle, and clear actions.
class GravelAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GravelAppBar({
    super.key,
    this.title = 'Gravel First',
    required this.measureEnabled,
    required this.onLocateMe,
    required this.onToggleMeasure,
    required this.onClearRoute,
  });

  final String title;
  final bool measureEnabled;
  final VoidCallback onLocateMe;
  final VoidCallback onToggleMeasure;
  final VoidCallback onClearRoute;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevation: 1,
      shadowColor: Colors.black26,
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.secondaryContainer,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: IconButton(
            tooltip: 'Hitta mig',
            icon: Icon(
              Icons.my_location,
              color: colorScheme.onSecondaryContainer,
              size: 22,
            ),
            onPressed: onLocateMe,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: measureEnabled ? Colors.green.shade600 : Colors.red.shade600,
            border: Border.all(
              color: measureEnabled
                  ? Colors.green.shade800
                  : Colors.red.shade800,
              width: 2,
            ),
          ),
          child: IconButton(
            tooltip: measureEnabled ? 'Stäng av mätläge' : 'Aktivera mätläge',
            icon: const Icon(Icons.straighten, color: Colors.white, size: 22),
            onPressed: onToggleMeasure,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.errorContainer,
            border: Border.all(color: colorScheme.error, width: 2),
          ),
          child: IconButton(
            tooltip: 'Rensa rutt',
            icon: Icon(
              Icons.delete_outline,
              color: colorScheme.onErrorContainer,
              size: 22,
            ),
            onPressed: onClearRoute,
          ),
        ),
      ],
    );
  }
}
