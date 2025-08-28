import 'package:flutter/material.dart';
import '../utils/coordinate_utils.dart';

/// Widget for displaying route distance measurements and controls
class DistancePanel extends StatefulWidget {
  final List<double> segmentMeters;
  final VoidCallback onUndo;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final ValueChanged<bool> onEditModeChanged;
  final ThemeData theme;
  final bool measureEnabled;
  final bool loopClosed;
  final bool canToggleLoop;
  final VoidCallback onToggleLoop;
  final bool editModeEnabled;
  final bool showDistanceMarkers;
  final ValueChanged<bool> onDistanceMarkersToggled;
  final double distanceInterval;
  final bool canUndo;

  const DistancePanel({
    super.key,
    required this.segmentMeters,
    required this.onUndo,
    required this.onSave,
    required this.onClear,
    required this.onEditModeChanged,
    required this.theme,
    required this.measureEnabled,
    required this.loopClosed,
    required this.canToggleLoop,
    required this.onToggleLoop,
    required this.editModeEnabled,
    required this.showDistanceMarkers,
    required this.onDistanceMarkersToggled,
    required this.distanceInterval,
    required this.canUndo,
  });

  @override
  State<DistancePanel> createState() => _DistancePanelState();
}

class _DistancePanelState extends State<DistancePanel>
    with TickerProviderStateMixin {
  bool _isExpanded = true; // Default to expanded
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  double get _totalMeters => widget.segmentMeters.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.theme.colorScheme.surface;
    final onSurface = widget.theme.colorScheme.onSurface;
    final primaryColor = widget.theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
        ), // Wide as screen, max 500px
        width: double.infinity, // Take full available width
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ), // Increased padding
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
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
              // Header row with title and primary actions
              GestureDetector(
                onTap: _toggleExpanded,
                child: Row(
                  children: [
                    Icon(Icons.tune, color: primaryColor, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kontroller',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.titleMedium?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Expand/collapse icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Primary action buttons (undo & save) - always visible
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: widget.theme.colorScheme.secondaryContainer
                            .withValues(alpha: 0.3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ångra senaste ändring',
                            icon: const Icon(Icons.undo, size: 18),
                            color: widget.canUndo
                                ? onSurface
                                : onSurface.withValues(alpha: 0.4),
                            onPressed: widget.canUndo ? widget.onUndo : null,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Spara rutt',
                            icon: const Icon(Icons.save, size: 18),
                            color: primaryColor,
                            onPressed: widget.onSave,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Rensa rutt',
                            icon: const Icon(Icons.clear_all, size: 18),
                            color: widget.theme.colorScheme.error,
                            onPressed: widget.segmentMeters.isEmpty
                                ? null
                                : widget.onClear,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Expandable content
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Control toggles row - now with more space (300px)
                    Row(
                      children: [
                        // Edit mode toggle - expanded
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: widget.editModeEnabled
                                  ? widget.theme.colorScheme.tertiaryContainer
                                        .withValues(alpha: 0.4)
                                  : widget.theme.colorScheme.surfaceContainer
                                        .withValues(alpha: 0.3),
                              border: Border.all(
                                color: widget.editModeEnabled
                                    ? widget.theme.colorScheme.tertiary
                                          .withValues(alpha: 0.4)
                                    : widget.theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: widget.editModeEnabled
                                      ? widget.theme.colorScheme.tertiary
                                      : onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Icon(
                                    Icons.edit_location,
                                    size: 18,
                                    color: widget.editModeEnabled
                                        ? widget
                                              .theme
                                              .colorScheme
                                              .onTertiaryContainer
                                        : onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                                Switch(
                                  value: widget.editModeEnabled,
                                  onChanged: widget.onEditModeChanged,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  activeThumbColor:
                                      widget.theme.colorScheme.tertiary,
                                  activeTrackColor: widget
                                      .theme
                                      .colorScheme
                                      .tertiary
                                      .withValues(alpha: 0.5),
                                  inactiveThumbColor:
                                      widget.theme.colorScheme.outline,
                                  inactiveTrackColor: widget
                                      .theme
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Distance markers toggle - expanded
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: widget.showDistanceMarkers
                                  ? widget.theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.9)
                                  : widget.theme.colorScheme.surfaceContainer
                                        .withValues(alpha: 0.3),
                              border: Border.all(
                                color: widget.showDistanceMarkers
                                    ? widget.theme.colorScheme.secondary
                                          .withValues(alpha: 0.8)
                                    : widget.theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: Colors.orange,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'km',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: widget.showDistanceMarkers,
                                  onChanged: widget.onDistanceMarkersToggled,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  activeThumbColor:
                                      widget.theme.colorScheme.secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.canToggleLoop) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: onSurface,
                            backgroundColor:
                                widget.theme.colorScheme.secondaryContainer,
                            elevation: 1,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          onPressed: widget.onToggleLoop,
                          icon: Icon(
                            widget.loopClosed ? Icons.link_off : Icons.link,
                            size: 16,
                          ),
                          label: Text(
                            widget.loopClosed ? 'Öppna slinga' : 'Stäng slinga',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Show edit mode instructions when edit mode is enabled
                    if (widget.editModeEnabled) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.tertiaryContainer
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.theme.colorScheme.tertiary.withValues(
                              alpha: 0.5,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 16,
                              color:
                                  widget.theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Redigeringsläge aktivt\n• Tryck på punkt för att välja\n• Långtryck på punkt för att ta bort\n• Tryck på + för att lägga till mellan punkter',
                                style: widget.theme.textTheme.bodySmall
                                    ?.copyWith(
                                      color: widget
                                          .theme
                                          .colorScheme
                                          .onTertiaryContainer,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Total: ${CoordinateUtils.formatDistance(_totalMeters)}',
                        style: widget.theme.textTheme.titleSmall?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Show helpful hint when not in edit mode but have points
                    if (!widget.editModeEnabled &&
                        widget.segmentMeters.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tryck på punkt för avstånd från start • Sätt på redigeringsläge för att ändra rutter',
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (widget.segmentMeters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Tryck på kartan för att lägga till punkter i redigeringsläge (grön redigeringsknapp)',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying route segments in a scrollable expansion tile
class RouteSegmentsPanel extends StatelessWidget {
  final List<double> segmentMeters;
  final bool loopClosed;
  final ThemeData theme;

  const RouteSegmentsPanel({
    super.key,
    required this.segmentMeters,
    required this.loopClosed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = theme.colorScheme.onSurface;

    if (segmentMeters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          backgroundColor: theme.colorScheme.surfaceContainer.withValues(
            alpha: 0.2,
          ),
          collapsedBackgroundColor: theme.colorScheme.surface,
          leading: Icon(
            Icons.analytics_outlined,
            size: 24,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            'Segment analys (${segmentMeters.length - (loopClosed ? 1 : 0)} segment${segmentMeters.length - (loopClosed ? 1 : 0) == 1 ? '' : ''}${loopClosed ? ' + loop' : ''})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          children: [
            Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ), // Limit height for scrolling
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Segment ${i + 1}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              CoordinateUtils.formatDistance(segmentMeters[i]),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (loopClosed && segmentMeters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.loop,
                              size: 16,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Loop slut → start',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onSurface,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          Text(
                            CoordinateUtils.formatDistance(segmentMeters.last),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
