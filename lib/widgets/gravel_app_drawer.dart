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
    required this.showTrvNvdbOverlay,
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
  final bool showTrvNvdbOverlay;
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
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Gravel First',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Import / Export',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    leading: Icon(
                      Icons.folder,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.map,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'GeoJSON',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        leading: ref.watch(isImportingProvider)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.upload_file,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        title: Text(
                          ref.watch(isImportingProvider)
                              ? 'Importerar GeoJSON...'
                              : 'Importera GeoJSON',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        enabled:
                            !ref.watch(isImportingProvider) &&
                            !ref.watch(isExportingProvider),
                        onTap: () async {
                          ref.read(isImportingProvider.notifier).state = true;
                          Navigator.of(context).pop();
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                          await onImportGeoJson();
                        },
                      ),
                      ListTile(
                        leading: ref.watch(isExportingProvider)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.download,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        title: Text(
                          ref.watch(isExportingProvider)
                              ? 'Exporterar GeoJSON...'
                              : 'Exportera GeoJSON',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        enabled:
                            !ref.watch(isImportingProvider) &&
                            !ref.watch(isExportingProvider),
                        onTap: () async {
                          ref.read(isExportingProvider.notifier).state = true;
                          Navigator.of(context).pop();
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                          await onExportGeoJson();
                        },
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.route,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'GPX',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        leading: ref.watch(isImportingProvider)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.upload_file,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        title: Text(
                          ref.watch(isImportingProvider)
                              ? 'Importerar GPX...'
                              : 'Importera GPX',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        enabled:
                            !ref.watch(isImportingProvider) &&
                            !ref.watch(isExportingProvider),
                        onTap: () async {
                          ref.read(isImportingProvider.notifier).state = true;
                          Navigator.of(context).pop();
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                          await onImportGpx();
                        },
                      ),
                      ListTile(
                        leading: ref.watch(isExportingProvider)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.download,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        title: Text(
                          ref.watch(isExportingProvider)
                              ? 'Exporterar GPX...'
                              : 'Exportera GPX',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        enabled:
                            !ref.watch(isImportingProvider) &&
                            !ref.watch(isExportingProvider),
                        onTap: () async {
                          ref.read(isExportingProvider.notifier).state = true;
                          Navigator.of(context).pop();
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                          await onExportGpx();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.layers,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'Grus-lager',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Visa OpenStreetMap/Overpass grusvägar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: ref.watch(gravelOverlayProvider),
                    onChanged: (v) =>
                        ref.read(gravelOverlayProvider.notifier).state = v,
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.terrain,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'TRV NVDB grus-lager',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Visa Trafikverket NVDB grusvägar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: showTrvNvdbOverlay,
                    onChanged: null,
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    leading: Icon(
                      Icons.straighten,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'Avståndsmarkeringar',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Lägg till markeringar längs rutt',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SwitchListTile(
                        secondary: const SizedBox(),
                        title: const Text('Visa markeringar'),
                        subtitle: distanceMarkers.isEmpty
                            ? const Text('Slå på för att visa markeringar')
                            : Text('${distanceMarkers.length} markeringar'),
                        value: ref.watch(distanceMarkersProvider),
                        onChanged: (v) {
                          if (v && distanceMarkers.isEmpty) {
                            // Auto-generate markers when enabling if none exist
                            onGenerateDistanceMarkers();
                          }
                          onToggleDistanceMarkers(v);
                        },
                      ),
                      // Distance interval slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avståndsintervall: ${(ref.watch(distanceIntervalProvider) / 1000).toStringAsFixed(1)} km',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Slider(
                              value: ref.watch(distanceIntervalProvider),
                              min: 500.0, // 500 meters minimum (0.5 km)
                              max: 5000.0, // 5 km maximum
                              divisions:
                                  9, // 0.5km, 1km, 1.5km, 2km, 2.5km, 3km, 3.5km, 4km, 4.5km, 5km
                              label:
                                  '${(ref.watch(distanceIntervalProvider) / 1000).toStringAsFixed(1)} km',
                              onChanged: (value) {
                                ref
                                        .read(distanceIntervalProvider.notifier)
                                        .state =
                                    value;
                                // Automatically regenerate markers when slider changes
                                onGenerateDistanceMarkers();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                  // Segment Analysis Toggle
                  SwitchListTile(
                    title: Text(
                      'Segment analys',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Visa detaljerad analys av rutt-segment',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: Icon(
                      Icons.analytics_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    value: showSegmentAnalysis,
                    onChanged: onToggleSegmentAnalysis,
                  ),
                  const SizedBox(height: 8),
                  // Saved Routes Section
                  ListTile(
                    leading: Icon(
                      Icons.bookmark,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: const Text('Sparade rutter'),
                    subtitle: Text('$savedRoutesCount/$maxSavedRoutes rutter'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.help,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () async {
                            if (onSavedRoutesInfo != null) {
                              onSavedRoutesInfo!();
                              return;
                            }
                            // Default help dialog
                            await showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.help,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Om sparade rutter'),
                                  ],
                                ),
                                content: const Text(
                                  'När du är inloggad sparas rutter till ditt konto och synkas via molnet. De blir tillgängliga på alla dina enheter när du är inloggad.\n\n'
                                  'Synlighet: Privata rutter är bara synliga för dig. Offentliga rutter kan ses av alla. När du öppnar en offentlig rutt kan du spara en egen kopia som privat.\n\n'
                                  'Offline: Senast använda rutter kan visas från cache och synkas när du blir online igen.\n\n'
                                  'Utan inloggning sparas rutter endast lokalt och kan försvinna om appdata rensas.\n\n'
                                  'Använd Import/Export för säkerhetskopiering eller för att flytta rutter till andra tjänster (GeoJSON/GPX).',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Information om sparade rutter',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: onSavedRoutesTap,
                  ),
                  // Save current route
                  ListTile(
                    leading: ref.watch(isSavingProvider)
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    title: Text(
                      ref.watch(isSavingProvider)
                          ? 'Sparar rutt...'
                          : 'Spara aktuell rutt',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    enabled: hasRoute && !ref.watch(isSavingProvider),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await SaveRouteDialog.show(
                        context,
                        onSave: onSaveRoute,
                        savedRoutesCount: savedRoutesCount,
                        maxSavedRoutes: maxSavedRoutes,
                        isAuthenticated: ref.watch(isSignedInProvider),
                        // initialName is provided by the parent via onSaveRoute context when available
                        // initialName: currentRouteName,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Stäng'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (kDebugMode) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Debug: Storage status shown in main screen footer',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ),
                  ],
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
}
