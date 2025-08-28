/// Saved Routes Mixin
///
/// Encapsulates loading and saving of routes via RouteService with
/// UI-friendly feedback (SnackBars) and provider wiring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_route.dart';
import '../providers/service_providers.dart';
import '../providers/loading_providers.dart';
import '../providers/ui_providers.dart';
import '../mixins/file_operations_mixin.dart';

mixin SavedRoutesMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, FileOperationsMixin<T> {
  // Local cache of saved routes for quick access in UI
  final List<SavedRoute> savedRoutes = [];

  // Maximum number of routes to keep (kept in sync with RouteService policy)
  int get maxSavedRoutes => 50;

  /// Should return true when storage is initialized/available check was completed
  bool get isStorageInitialized;

  /// Load all saved routes into [savedRoutes].
  Future<void> loadSavedRoutes() async {
    try {
      final routeService = ref.read(routeServiceProvider);
      final routes = await routeService.loadSavedRoutes();
      if (!mounted) return;
      setState(() {
        savedRoutes
          ..clear()
          ..addAll(routes);
      });
    } catch (e) {
      debugPrint('Error loading saved routes: $e');
    }
  }

  /// Save current route points with a name, with validation and feedback.
  Future<void> saveCurrentRoute(
    String name,
    List<LatLng> routePoints, {
    bool isPublic = false,
  }) async {
    if (routePoints.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen rutt att spara')));
      return;
    }

    // Ensure initialization and storage availability
    final routeService = ref.read(routeServiceProvider);
    if (!isStorageInitialized) {
      debugPrint('RouteService not initialized yet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('App is still initializing. Please wait...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!routeService.isStorageAvailable()) {
      debugPrint(
        '❌ [${DateTime.now().toIso8601String()}] Storage not available during save attempt',
      );
      debugPrint(
        '🔍 [${DateTime.now().toIso8601String()}] Storage diagnostics during save:',
      );
      final saveDiagnostics = routeService.getStorageDiagnostics();
      for (final line in saveDiagnostics.split('\n')) {
        if (line.trim().isNotEmpty) debugPrint('   $line');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Route saving unavailable. This happens in private browsing mode or when browser storage is disabled.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Export instead',
              onPressed: () => exportGeoJsonRoute(routePoints),
            ),
          ),
        );
      }
      return;
    }

    ref.read(isSavingProvider.notifier).state = true;

    try {
      // Add a tiny delay so the loading indicator is visible
      await Future.delayed(const Duration(milliseconds: 100));

      // Use SyncedRouteService for cloud sync capability
      final syncedService = ref.read(syncedRouteServiceProvider);
      await syncedService.saveCurrentRoute(
        name: name,
        routePoints: routePoints,
        loopClosed: ref.watch(loopClosedProvider),
        description: null,
        isPublic: isPublic,
      );

      await loadSavedRoutes();

      if (mounted) {
        final syncMessage = ref.watch(isSignedInProvider)
            ? (isPublic ? ' och synkad som offentlig' : ' och synkad privat')
            : ' lokalt';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rutt "$name" sparad$syncMessage')),
        );
      }
    } catch (e) {
      debugPrint('Error saving route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving route: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Export instead',
              onPressed: () => exportGeoJsonRoute(routePoints),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(isSavingProvider.notifier).state = false;
      }
    }
  }
}
