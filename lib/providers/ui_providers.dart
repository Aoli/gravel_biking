import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for measure mode state
///
/// Controls whether the map is in measurement mode (true) or view mode (false).
/// In measure mode, users can add/edit route points.
/// In view mode, only start/end points are shown with enhanced visualization.
final measureModeProvider = StateProvider<bool>((ref) => false);

/// Provider for gravel overlay visibility
///
/// Controls whether the gravel roads overlay is displayed on the map.
final gravelOverlayProvider = StateProvider<bool>((ref) => false);

/// Provider for distance markers visibility
///
/// Controls whether distance markers are shown along the route.
final distanceMarkersProvider = StateProvider<bool>((ref) => false);

/// Provider for distance marker interval
///
/// Sets the interval (in meters) between distance markers on the route.
/// Default is 1000 meters (1 km).
final distanceIntervalProvider = StateProvider<double>((ref) => 1000.0);

/// Provider for current editing index
///
/// Holds the index of the route point currently being edited.
/// Null means no point is being edited.
final editingIndexProvider = StateProvider<int?>((ref) => null);
