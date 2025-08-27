# Riverpod Migration Guide

## Overview

This document describes the migration of Gravel First from basic StatefulWidget state management to Riverpod for better state coordination, testing, and maintainability.

## Why Riverpod?

### Problems with Current State Management
- **Complex State Coordination**: 40+ `setState` calls managing interdependent variables
- **Cross-Screen Synchronization Issues**: State not properly synchronized between map and saved routes screens
- **Async State Inconsistency**: Loading states managed separately with potential race conditions
- **Hard to Test**: State logic coupled with UI widgets
- **Performance**: Full widget rebuilds instead of selective rebuilds

### Benefits of Riverpod
- **Type Safety**: Compile-time guarantees for state access
- **Better Coordination**: Related states update together automatically  
- **Cleaner Architecture**: Separation of state logic from UI
- **Easier Testing**: State providers can be tested in isolation
- **Performance**: Selective widget rebuilds only when relevant state changes
- **DevTools Integration**: Excellent debugging capabilities

## Core Riverpod Concepts

### 1. Providers
Providers are the building blocks of Riverpod. They hold state and expose it to widgets.

```dart
// Simple state provider
final measureModeProvider = StateProvider<bool>((ref) => false);

// Complex state with business logic
final routeStateProvider = StateNotifierProvider<RouteStateNotifier, RouteState>(
  (ref) => RouteStateNotifier(ref.read(routeServiceProvider)),
);
```

### 2. Consumers
Widgets that need to read state from providers.

```dart
// ConsumerWidget - stateless widget that can read providers
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measureMode = ref.watch(measureModeProvider);
    return Switch(
      value: measureMode,
      onChanged: (value) => ref.read(measureModeProvider.notifier).state = value,
    );
  }
}

// ConsumerStatefulWidget - stateful widget that can read providers
class MyStatefulWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends ConsumerState<MyStatefulWidget> {
  @override
  Widget build(BuildContext context) {
    final measureMode = ref.watch(measureModeProvider);
    return Text('Measure mode: $measureMode');
  }
}
```

### 3. StateNotifier
For complex state with business logic.

```dart
class RouteState {
  final List<LatLng> points;
  final bool isLoopClosed;
  final bool measureEnabled;
  final int? editingIndex;
  
  RouteState({
    this.points = const [],
    this.isLoopClosed = false,
    this.measureEnabled = false,
    this.editingIndex,
  });
  
  RouteState copyWith({
    List<LatLng>? points,
    bool? isLoopClosed,
    bool? measureEnabled,
    int? editingIndex,
  }) => RouteState(
    points: points ?? this.points,
    isLoopClosed: isLoopClosed ?? this.isLoopClosed,
    measureEnabled: measureEnabled ?? this.measureEnabled,
    editingIndex: editingIndex ?? this.editingIndex,
  );
}

class RouteStateNotifier extends StateNotifier<RouteState> {
  RouteStateNotifier(this._routeService) : super(RouteState());
  
  final RouteService _routeService;
  
  void toggleMeasureMode() {
    state = state.copyWith(measureEnabled: !state.measureEnabled);
  }
  
  void addPoint(LatLng point) {
    state = state.copyWith(
      points: [...state.points, point],
      isLoopClosed: false, // Adding point opens the loop
    );
  }
}
```

## Migration Strategy

### Phase 1: Setup and Basic State (Current)
1. ✅ Add Riverpod dependencies
2. ⏳ Wrap app with ProviderScope
3. ⏳ Create basic state providers
4. ⏳ Migrate simple toggle states (measure mode, overlays)

### Phase 2: Complex Route State
1. Create RouteState class with all route-related data
2. Create RouteStateNotifier for business logic
3. Migrate point management, loop detection, editing state

### Phase 3: Service Integration
1. Create service providers (RouteService, LocationService)
2. Connect state notifiers with services
3. Handle async operations properly

### Phase 4: UI Migration
1. Convert main map screen to ConsumerStatefulWidget
2. Convert drawer and dialogs to use providers
3. Ensure proper rebuilds and performance

### Phase 5: Cross-Screen State
1. Migrate SavedRoutesPage to use providers
2. Remove callback-based state passing
3. Ensure state persistence across navigation

### Phase 6: Testing and Cleanup
1. Update existing tests to use Riverpod testing utilities
2. Add tests for new state providers
3. Remove old setState code
4. Performance optimization

## File Organization

```
lib/
├── providers/           # Riverpod providers
│   ├── route_provider.dart         # Route state management
│   ├── ui_provider.dart             # UI state (overlays, loading)
│   ├── location_provider.dart       # GPS and location state
│   └── service_providers.dart       # Service instances
├── state/              # State classes and notifiers
│   ├── route_state.dart            # Route state model
│   ├── route_notifier.dart         # Route business logic
│   └── ui_state.dart               # UI state models
└── ...existing structure
```

## Implementation Notes

### State Provider Types
- **StateProvider**: Simple state (booleans, numbers, strings)
- **StateNotifierProvider**: Complex state with business logic
- **Provider**: Read-only computed values
- **FutureProvider**: Async data fetching
- **StreamProvider**: Reactive data streams

### Performance Considerations
- Use `ref.watch()` for listening to changes (rebuilds widget)
- Use `ref.read()` for one-time access (no rebuilds)
- Use `select()` to listen to specific parts of state only

### Testing Strategy
- Test state providers independently of UI
- Use `ProviderContainer` for testing state logic
- Mock services and dependencies easily
- Test state transitions and business logic

## Expected Benefits After Migration

1. **Cleaner Code**: State logic separated from UI
2. **Better Performance**: Selective rebuilds instead of full screen rebuilds
3. **Easier Debugging**: Clear state flow and DevTools integration
4. **Improved Testing**: Isolated state logic testing
5. **Better Coordination**: Related states always stay in sync
6. **Reduced Bugs**: Type safety and immutable state patterns

## Migration Checklist

### Phase 1: Setup ✅

- [x] Add flutter_riverpod dependency
- [x] Wrap app with ProviderScope
- [x] Create basic providers for simple states
- [x] Convert one simple widget to Consumer
- [x] Test basic Riverpod functionality

### Phase 2: Route State Management
- [ ] Create RouteState model class
- [ ] Create RouteStateNotifier
- [ ] Create route provider
- [ ] Test route state management

### Phase 3: UI State Management  
- [ ] Create UI state providers for overlays, loading states
- [ ] Create location state provider
- [ ] Migrate simple toggle switches

### Phase 4: Main Screen Migration
- [ ] Convert GravelStreetsMap to ConsumerStatefulWidget
- [ ] Replace setState with provider state updates
- [ ] Ensure all UI updates work correctly

### Phase 5: Service Integration
- [ ] Create service providers
- [ ] Connect StateNotifiers with services
- [ ] Handle async operations with proper loading states

### Phase 6: Secondary Screens
- [ ] Migrate SavedRoutesPage to use providers
- [ ] Remove callback-based navigation state
- [ ] Test cross-screen state persistence

### Phase 7: Testing & Cleanup
- [ ] Update existing tests for Riverpod
- [ ] Add provider testing
- [ ] Remove old setState code
- [ ] Performance testing and optimization

---

*This document will be updated as the migration progresses.*
