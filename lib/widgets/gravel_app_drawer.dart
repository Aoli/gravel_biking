import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/loading_providers.dart';
import '../providers/ui_providers.dart';
import '../providers/service_providers.dart';
import 'save_route_dialog.dart';

class GravelAppDrawer extends ConsumerWidget {
  const GravelAppDrawer({
    super.key,
    required this.onImportGeoJson,
    required this.onExportGeoJson,
    required this.onImportGpx,
    required this.onExportGpx,
    required this.onSaveRoute,
    required this.hasRoute,
    required this.savedRoutesCount,
    required this.maxSavedRoutes,
    required this.distanceMarkers,
    required this.onToggleDistanceMarkers,
    required this.onGenerateDistanceMarkers,
    required this.onClearDistanceMarkers,
    required this.onSavedRoutesTap,
    this.onSavedRoutesInfo,
    required this.showSegmentAnalysis,
    required this.onToggleSegmentAnalysis,
    required this.footer,
  });

  final Future<void> Function() onImportGeoJson;
  final Future<void> Function() onExportGeoJson;
  final Future<void> Function() onImportGpx;
  final Future<void> Function() onExportGpx;
  final Future<void> Function(String name, bool isPublic) onSaveRoute;
  final bool hasRoute;
  final int savedRoutesCount;
  final int maxSavedRoutes;

  final List<LatLng> distanceMarkers;
  final void Function(bool value) onToggleDistanceMarkers;
  final VoidCallback onGenerateDistanceMarkers;
  final VoidCallback onClearDistanceMarkers;
  final VoidCallback onSavedRoutesTap;
  final VoidCallback? onSavedRoutesInfo;
  final bool showSegmentAnalysis;
  final ValueChanged<bool> onToggleSegmentAnalysis;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NVDB is available on all platforms; on web it uses NVDB_PROXY_BASE if provided
    // and falls back to same-origin (Firebase Hosting rewrite) otherwise.
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Enhanced Header
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.terrain,
                                color: colorScheme.onPrimary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Gravel First',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            'Planera dina grusäventyr',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.9,
                              ),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const SizedBox(height: 8),

                  // Section 1: Snabbåtgärder (Quick Actions)
                  _buildSectionHeader(
                    context,
                    'Snabbåtgärder',
                    Icons.flash_on,
                    colorScheme.primary,
                  ),

                  // Save current route - most common action
                  _buildActionTile(
                    context,
                    icon: ref.watch(isSavingProvider)
                        ? null
                        : Icons.bookmark_add,
                    title: ref.watch(isSavingProvider)
                        ? 'Sparar rutt...'
                        : 'Spara aktuell rutt',
                    subtitle: hasRoute
                        ? 'Spara din nuvarande rutt för senare'
                        : 'Rita en rutt för att kunna spara den',
                    enabled: hasRoute && !ref.watch(isSavingProvider),
                    isLoading: ref.watch(isSavingProvider),
                    primaryColor: colorScheme.primary,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await SaveRouteDialog.show(
                        context,
                        onSave: onSaveRoute,
                        savedRoutesCount: savedRoutesCount,
                        maxSavedRoutes: maxSavedRoutes,
                        isAuthenticated: ref.watch(isSignedInProvider),
                      );
                    },
                  ),

                  // Saved Routes
                  _buildActionTile(
                    context,
                    icon: Icons.folder_open,
                    title: 'Sparade rutter',
                    subtitle: 'Visa och hantera dina rutter',
                    onTap: onSavedRoutesTap,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.help_outline,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => _showSavedRoutesHelp(context),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Information om sparade rutter',
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 2: Kartinställningar (Map Settings)
                  _buildSectionHeader(
                    context,
                    'Kartinställningar',
                    Icons.layers,
                    colorScheme.secondary,
                  ),

                  // Gravel overlay
                  _buildSwitchTile(
                    context,
                    icon: Icons.terrain,
                    title: 'Visa grusvägar',
                    subtitle: 'OpenStreetMap grusvägar och stigar',
                    value: ref.watch(gravelOverlayProvider),
                    onChanged: (v) =>
                        ref.read(gravelOverlayProvider.notifier).state = v,
                  ),

                  // Distance markers section
                  _buildDistanceMarkersSection(context, ref),

                  const SizedBox(height: 16),

                  // Section 3: Import & Export
                  _buildSectionHeader(
                    context,
                    'Import & Export',
                    Icons.import_export,
                    colorScheme.tertiary,
                  ),

                  _buildFileOperationsSection(context, ref),

                  const SizedBox(height: 16),

                  // Section 4: Avancerat (Advanced)
                  _buildSectionHeader(
                    context,
                    'Avancerat',
                    Icons.tune,
                    colorScheme.outline,
                  ),

                  // Segment Analysis Toggle
                  _buildSwitchTile(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'Segmentanalys',
                    subtitle: 'Detaljerad analys av ruttsegment',
                    value: showSegmentAnalysis,
                    onChanged: onToggleSegmentAnalysis,
                  ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    _buildDebugSection(context),
                  ],

                  const SizedBox(height: 16),

                  // Close button
                  _buildActionTile(
                    context,
                    icon: Icons.close,
                    title: 'Stäng meny',
                    subtitle: 'Återgå till kartan',
                    onTap: () => Navigator.of(context).pop(),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
            const Divider(height: 1),
            footer,
          ],
        ),
      ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build action tiles
  Widget _buildActionTile(
    BuildContext context, {
    IconData? icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    bool isLoading = false,
    Color? primaryColor,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: enabled
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainer.withValues(alpha: 0.3),
      ),
      child: ListTile(
        enabled: enabled,
        leading: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor ?? colorScheme.primary,
                ),
              )
            : icon != null
            ? Icon(
                icon,
                color: enabled
                    ? (primaryColor ?? colorScheme.onSurface)
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              )
            : null,
        trailing: trailing,
        onTap: enabled ? onTap : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Helper method to build switch tiles
  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool isDisabled = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDisabled
            ? colorScheme.surfaceContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLowest,
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: isDisabled
              ? colorScheme.onSurface.withValues(alpha: 0.5)
              : colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
            color: isDisabled
                ? colorScheme.onSurface.withValues(alpha: 0.5)
                : colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: isDisabled
                      ? colorScheme.onSurface.withValues(alpha: 0.4)
                      : colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        value: value,
        onChanged: isDisabled ? null : onChanged,
      ),
    );
  }

  // Helper method to build distance markers section
  Widget _buildDistanceMarkersSection(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.straighten, color: colorScheme.onSurface),
            title: Text(
              'Avståndsmarkeringar',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            subtitle: distanceMarkers.isEmpty
                ? const Text('Rita en rutt för att lägga till markeringar')
                : Text('${distanceMarkers.length} markeringar visas'),
            value: ref.watch(distanceMarkersProvider),
            onChanged: (v) {
              if (v && distanceMarkers.isEmpty) {
                onGenerateDistanceMarkers();
              }
              onToggleDistanceMarkers(v);
            },
          ),
          if (ref.watch(distanceMarkersProvider)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Intervall: ${(ref.watch(distanceIntervalProvider) / 1000).toStringAsFixed(1)} km',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: ref.watch(distanceIntervalProvider),
                    min: 500.0,
                    max: 5000.0,
                    divisions: 9,
                    label:
                        '${(ref.watch(distanceIntervalProvider) / 1000).toStringAsFixed(1)} km',
                    onChanged: (value) {
                      ref.read(distanceIntervalProvider.notifier).state = value;
                      onGenerateDistanceMarkers();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build file operations section
  Widget _buildFileOperationsSection(BuildContext context, WidgetRef ref) {
    final isImporting = ref.watch(isImportingProvider);
    final isExporting = ref.watch(isExportingProvider);
    final isOperationInProgress = isImporting || isExporting;

    return Column(
      children: [
        // GeoJSON operations
        _buildActionTile(
          context,
          icon: isImporting ? null : Icons.file_upload,
          title: isImporting ? 'Importerar GeoJSON...' : 'Importera GeoJSON',
          subtitle: 'Läs in rutt från GeoJSON-fil',
          enabled: !isOperationInProgress,
          isLoading: isImporting,
          onTap: () async {
            ref.read(isImportingProvider.notifier).state = true;
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            await onImportGeoJson();
          },
        ),

        _buildActionTile(
          context,
          icon: isExporting ? null : Icons.file_download,
          title: isExporting ? 'Exporterar GeoJSON...' : 'Exportera GeoJSON',
          subtitle: hasRoute
              ? 'Spara rutt som GeoJSON-fil'
              : 'Rita en rutt för att exportera',
          enabled: hasRoute && !isOperationInProgress,
          isLoading: isExporting,
          onTap: () async {
            ref.read(isExportingProvider.notifier).state = true;
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            await onExportGeoJson();
          },
        ),

        const SizedBox(height: 8),

        // GPX operations
        _buildActionTile(
          context,
          icon: isImporting ? null : Icons.route,
          title: isImporting ? 'Importerar GPX...' : 'Importera GPX',
          subtitle: 'Läs in rutt från GPX-fil',
          enabled: !isOperationInProgress,
          isLoading: isImporting,
          onTap: () async {
            ref.read(isImportingProvider.notifier).state = true;
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            await onImportGpx();
          },
        ),

        _buildActionTile(
          context,
          icon: isExporting ? null : Icons.route,
          title: isExporting ? 'Exporterar GPX...' : 'Exportera GPX',
          subtitle: hasRoute
              ? 'Spara rutt som GPX-fil'
              : 'Rita en rutt för att exportera',
          enabled: hasRoute && !isOperationInProgress,
          isLoading: isExporting,
          onTap: () async {
            ref.read(isExportingProvider.notifier).state = true;
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            await onExportGpx();
          },
        ),
      ],
    );
  }

  // Helper method to build debug section
  Widget _buildDebugSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.orange[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Debug: Storage status visas i footer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to show saved routes help
  void _showSavedRoutesHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Om sparade rutter'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'När du är inloggad sparas rutter till ditt konto och synkas via molnet. '
            'De blir tillgängliga på alla dina enheter när du är inloggad.\n\n'
            '📱 Synlighet: Privata rutter är bara synliga för dig. Offentliga rutter kan ses av alla. '
            'När du öppnar en offentlig rutt kan du spara en egen kopia som privat.\n\n'
            '🔄 Offline: Senast använda rutter kan visas från cache och synkas när du blir online igen.\n\n'
            '⚠️ Utan inloggning sparas rutter endast lokalt och kan försvinna om appdata rensas.\n\n'
            '💾 Använd Import/Export för säkerhetskopiering eller för att flytta rutter till andra tjänster.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Förstått'),
          ),
        ],
      ),
    );
  }
}
