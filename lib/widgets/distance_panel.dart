import 'package:flutter/material.dart';
import '../utils/coordinate_utils.dart';

/// Widget for displaying route distance measurements and controls
class DistancePanel extends StatelessWidget {
  final List<double> segmentMeters;
  final VoidCallback onUndo;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final ThemeData theme;
  final bool measureEnabled;
  final bool loopClosed;
  final bool canToggleLoop;
  final VoidCallback onToggleLoop;
  final int? editingIndex;
  final VoidCallback onCancelEdit;

  const DistancePanel({
    super.key,
    required this.segmentMeters,
    required this.onUndo,
    required this.onSave,
    required this.onClear,
    required this.theme,
    required this.measureEnabled,
    required this.loopClosed,
    required this.canToggleLoop,
    required this.onToggleLoop,
    required this.editingIndex,
    required this.onCancelEdit,
  });

  double get _totalMeters => segmentMeters.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black26,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.straighten_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mätning',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ångra senaste punkt',
                          icon: const Icon(Icons.undo_outlined, size: 18),
                          color: onSurface,
                          onPressed: onUndo,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Spara rutt',
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 18,
                          ),
                          color: primaryColor,
                          onPressed: onSave,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Rensa rutt',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: theme.colorScheme.error,
                          onPressed: onClear,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canToggleLoop) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: onSurface,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      elevation: 1,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: onToggleLoop,
                    icon: Icon(
                      loopClosed
                          ? Icons.link_off_outlined
                          : Icons.link_outlined,
                      size: 16,
                    ),
                    label: Text(
                      loopClosed ? 'Öppna slinga' : 'Stäng slinga',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (editingIndex != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Redigerar punkt #${editingIndex! + 1} — tryck på kartan för att flytta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Avbryt redigering',
                        icon: const Icon(Icons.close_outlined, size: 16),
                        color: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onCancelEdit,
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total: ${CoordinateUtils.formatDistance(_totalMeters)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (segmentMeters.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tryck på kartan för att lägga till punkter i redigeringsläge (grön redigeringsknapp)',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            int i = 0;
                            i < segmentMeters.length - (loopClosed ? 1 : 0);
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Segment ${i + 1}: ${CoordinateUtils.formatDistance(segmentMeters[i])}',
                                style: TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          if (loopClosed && segmentMeters.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Loop segment: ${CoordinateUtils.formatDistance(segmentMeters.last)}',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
