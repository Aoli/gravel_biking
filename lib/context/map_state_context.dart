import 'package:flutter/material.dart';

/// Holds the UI state for the map that needs to be shared with child widgets
class MapUIState {
  final bool measureEnabled;
  final bool editModeEnabled;
  final bool loopClosed;
  final int? editingIndex;

  const MapUIState({
    required this.measureEnabled,
    required this.editModeEnabled,
    required this.loopClosed,
    this.editingIndex,
  });

  MapUIState copyWith({
    bool? measureEnabled,
    bool? editModeEnabled,
    bool? loopClosed,
    int? editingIndex,
  }) {
    return MapUIState(
      measureEnabled: measureEnabled ?? this.measureEnabled,
      editModeEnabled: editModeEnabled ?? this.editModeEnabled,
      loopClosed: loopClosed ?? this.loopClosed,
      editingIndex: editingIndex ?? this.editingIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapUIState &&
          measureEnabled == other.measureEnabled &&
          editModeEnabled == other.editModeEnabled &&
          loopClosed == other.loopClosed &&
          editingIndex == other.editingIndex;

  @override
  int get hashCode =>
      measureEnabled.hashCode ^
      editModeEnabled.hashCode ^
      loopClosed.hashCode ^
      editingIndex.hashCode;
}

/// InheritedWidget that provides map UI state to child widgets
class MapStateProvider extends InheritedWidget {
  final MapUIState state;

  const MapStateProvider({
    super.key,
    required this.state,
    required super.child,
  });

  static MapUIState? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<MapStateProvider>();
    return provider?.state;
  }

  static MapUIState of(BuildContext context) {
    final state = maybeOf(context);
    assert(state != null, 'MapStateProvider not found in widget tree');
    return state!;
  }

  @override
  bool updateShouldNotify(MapStateProvider oldWidget) {
    return state != oldWidget.state;
  }
}
