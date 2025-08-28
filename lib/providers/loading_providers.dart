import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for route saving loading state
///
/// True when a route save operation is in progress.
final isSavingProvider = StateProvider<bool>((ref) => false);

/// Provider for route importing loading state
///
/// True when a route import operation (GeoJSON/GPX) is in progress.
final isImportingProvider = StateProvider<bool>((ref) => false);

/// Provider for route exporting loading state
///
/// True when a route export operation is in progress.
final isExportingProvider = StateProvider<bool>((ref) => false);

/// Provider for general loading state
///
/// Used for map data loading, GPS operations, etc.
final isLoadingProvider = StateProvider<bool>((ref) => false);
