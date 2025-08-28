# State Management – Riverpod Implementation Guide

## Table of Contents

1. [Riverpod Foundation](#1-riverpod-foundation)
2. [Provider Architecture](#2-provider-architecture)
3. [Implementation Status](#3-implementation-status)
4. [Migration Strategy](#4-migration-strategy)
5. [Testing Patterns](#5-testing-patterns)
6. [Best Practices](#6-best-practices)

---

## 1. Riverpod Foundation

### 1.1 Core Concepts

Implement Riverpod as the primary state management solution for reactive UI updates and clean architecture:

- **Providers**: Immutable data containers that notify dependents of changes
- **Consumers**: Widgets that listen to provider changes and rebuild automatically
- **Ref**: Reference object for accessing providers and managing dependencies
- **Notifiers**: Advanced state management with business logic encapsulation

### 1.2 Technology Stack

Use these specific Riverpod packages and versions:

```yaml
dependencies:
  flutter_riverpod: ^2.4.9    # Core Riverpod functionality
  
dev_dependencies:
  riverpod_test: ^2.0.0       # Testing utilities for providers
```

### 1.3 App Configuration

Configure the app with ProviderScope for Riverpod functionality:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

---

## 2. Provider Architecture

### 2.1 Provider Categories

Organize providers by functionality and complexity:

#### 2.1.1 UI State Providers (`ui_providers.dart`)

Simple state management for UI toggles and configurations:

```dart
// Measurement mode toggle (view/measure)
final measureModeProvider = StateProvider<bool>((ref) => false);

// Gravel overlay visibility
final gravelOverlayProvider = StateProvider<bool>((ref) => true);

// Distance markers visibility and configuration
final distanceMarkersProvider = StateProvider<bool>((ref) => false);
final distanceIntervalProvider = StateProvider<double>((ref) => 1.0);

// Point editing state
final editingIndexProvider = StateProvider<int?>((ref) => null);
```

#### 2.1.2 Loading State Providers (`loading_providers.dart`)

Manage loading states for async operations:

```dart
// File operation loading states
final isSavingProvider = StateProvider<bool>((ref) => false);
final isImportingProvider = StateProvider<bool>((ref) => false);
final isExportingProvider = StateProvider<bool>((ref) => false);
final isLoadingProvider = StateProvider<bool>((ref) => false);

// API operation loading states
final isLoadingGravelDataProvider = StateProvider<bool>((ref) => false);
final isLoadingLocationProvider = StateProvider<bool>((ref) => false);
```

#### 2.1.3 Service Instance Providers (`service_providers.dart`)

Manage service instances and their initialization:

```dart
// Service singletons
final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

// Service initialization state
final routeServiceInitializedProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(routeServiceProvider);
  await service.initialize();
  return true;
});
```

### 2.2 Complex State Management

#### 2.2.1 Route State Provider (Future Implementation)

Design comprehensive route state management:

```dart
@immutable
class RouteState {
  final List<LatLng> points;
  final bool loopClosed;
  final bool measureEnabled;
  final int? editingIndex;
  final List<Marker> distanceMarkers;
  final double totalDistance;
  
  const RouteState({
    required this.points,
    required this.loopClosed,
    required this.measureEnabled,
    this.editingIndex,
    required this.distanceMarkers,
    required this.totalDistance,
  });
  
  RouteState copyWith({
    List<LatLng>? points,
    bool? loopClosed,
    bool? measureEnabled,
    int? editingIndex,
    List<Marker>? distanceMarkers,
    double? totalDistance,
  }) {
    return RouteState(
      points: points ?? this.points,
      loopClosed: loopClosed ?? this.loopClosed,
      measureEnabled: measureEnabled ?? this.measureEnabled,
      editingIndex: editingIndex ?? this.editingIndex,
      distanceMarkers: distanceMarkers ?? this.distanceMarkers,
      totalDistance: totalDistance ?? this.totalDistance,
    );
  }
}

class RouteStateNotifier extends StateNotifier<RouteState> {
  RouteStateNotifier() : super(const RouteState(
    points: [],
    loopClosed: false,
    measureEnabled: false,
    distanceMarkers: [],
    totalDistance: 0.0,
  ));
  
  void addPoint(LatLng point) {
    state = state.copyWith(
      points: [...state.points, point],
      totalDistance: _calculateTotalDistance([...state.points, point]),
    );
  }
  
  void removePoint(int index) {
    final newPoints = List<LatLng>.from(state.points)..removeAt(index);
    state = state.copyWith(
      points: newPoints,
      totalDistance: _calculateTotalDistance(newPoints),
    );
  }
  
  void toggleLoop() {
    state = state.copyWith(
      loopClosed: !state.loopClosed,
      totalDistance: _calculateTotalDistance(state.points, !state.loopClosed),
    );
  }
  
  double _calculateTotalDistance(List<LatLng> points, [bool? loopClosed]) {
    // Implementation of distance calculation
    return 0.0; // Placeholder
  }
}

final routeStateProvider = StateNotifierProvider<RouteStateNotifier, RouteState>((ref) {
  return RouteStateNotifier();
});
```

### 2.3 Provider Dependencies

Establish clear provider dependency relationships:

```dart
// Computed providers that depend on other providers
final routeInfoProvider = Provider<RouteInfo>((ref) {
  final points = ref.watch(routeStateProvider).points;
  final loopClosed = ref.watch(routeStateProvider).loopClosed;
  final measureEnabled = ref.watch(measureModeProvider);
  
  return RouteInfo(
    pointCount: points.length,
    canClose: points.length >= 3,
    canEdit: measureEnabled,
    segments: _calculateSegments(points, loopClosed),
  );
});

// Async providers for external data
final savedRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  final service = ref.read(routeServiceProvider);
  return await service.getAllRoutes();
});
```

---

## 3. Implementation Status

### 3.1 Completed Implementation

#### Phase 1: Basic Setup ✅

**What Was Completed:**

1. **Dependencies Configuration**:
   - Added `flutter_riverpod: ^2.4.9` to pubspec.yaml
   - Successfully installed and configured dependencies

2. **App Integration**:
   - Wrapped app with `ProviderScope` in main.dart
   - Created provider directory structure under `lib/providers/`

3. **Basic Provider Creation**:
   - `ui_providers.dart`: Simple state providers for UI toggles
   - `loading_providers.dart`: Loading state management
   - `service_providers.dart`: Service instance providers

4. **Demo Integration**:
   - Created `RiverpodDemoWidget` for testing functionality
   - Validated basic state management works correctly
   - Confirmed app compiles and runs without breaking changes

#### Phase 2: Measure Mode Toggle ✅

**What Was Completed:**

1. **Widget Conversion**:
   - Converted `GravelStreetsMap` from `StatefulWidget` to `ConsumerStatefulWidget`
   - Updated state class from `State<T>` to `ConsumerState<T>`
   - Added proper Riverpod imports

2. **State Migration**:
   - Removed local `bool _measureEnabled` variable
   - Migrated all references to use `measureModeProvider`
   - Updated toggle button to use Riverpod state management

3. **UI Integration**:
   - Connected button colors to reactive provider state
   - Updated tooltips and visual feedback automatically
   - Integrated business logic with provider state

4. **Testing Validation**:
   - All 104 tests continue passing
   - Flutter analyzer remains clean
   - No breaking changes to existing functionality

**Benefits Achieved:**
- Removed one `setState` call
- Cleaner state management architecture
- Better performance through selective widget rebuilds
- Enhanced testability of state logic
- Consistent state across components

### 3.2 Current Status Summary

**✅ Implemented:**
- Basic provider infrastructure
- Simple UI state management (measure mode toggle)
- Loading state providers
- Service instance providers
- Demo widget for testing

**🔄 In Progress:**
- Additional UI toggle migrations (gravel overlay, distance markers)
- Complex state management (RouteState)

**📋 Planned:**
- Complete migration of all StatefulWidget state to Riverpod
- Advanced state management patterns
- Provider testing implementation

---

## 4. Migration Strategy

### 4.1 Migration Phases

#### Phase 3: Simple UI Toggles (Next Priority)

Convert remaining simple boolean state variables:

1. **Gravel Overlay Toggle**:
   ```dart
   // Replace: bool _showGravelOverlay = true;
   // With: ref.watch(gravelOverlayProvider)
   
   // Update toggle logic:
   onChanged: (value) => ref.read(gravelOverlayProvider.notifier).state = value
   ```

2. **Distance Markers Toggle**:
   ```dart
   // Replace: bool _showDistanceMarkers = false;
   // With: ref.watch(distanceMarkersProvider)
   ```

3. **Distance Interval Slider**:
   ```dart
   // Replace: double _distanceInterval = 1.0;
   // With: ref.watch(distanceIntervalProvider)
   ```

#### Phase 4: Complex State Migration

Design and implement comprehensive route state management:

1. **RouteState Model Creation**:
   - Define immutable RouteState class
   - Implement RouteStateNotifier with business logic
   - Create computed providers for derived state

2. **State Variable Migration**:
   - Move route points to RouteState
   - Migrate loop closure state
   - Transfer distance markers to state management
   - Consolidate editing state

3. **Business Logic Integration**:
   - Move distance calculations to notifier
   - Implement undo/redo functionality
   - Handle route persistence operations

#### Phase 5: Advanced Patterns

Implement advanced state management patterns:

1. **Provider Composition**:
   - Combine multiple providers for complex operations
   - Implement provider dependencies and computed values
   - Create provider families for parameterized state

2. **Async State Management**:
   - Handle loading states with FutureProvider
   - Implement error handling patterns
   - Manage API call state and caching

### 4.2 Migration Best Practices

#### 4.2.1 Incremental Migration

Follow these principles for safe migration:

- **One Feature at a Time**: Migrate individual features rather than wholesale changes
- **Maintain Compatibility**: Ensure existing functionality works during migration
- **Test at Each Step**: Validate functionality after each migration phase
- **Rollback Strategy**: Keep previous implementation until new version is proven

#### 4.2.2 State Design Patterns

Use these patterns for consistent state management:

- **Immutable State**: Use immutable data classes for all state objects
- **Single Source of Truth**: Each piece of state should have one provider
- **Computed Values**: Derive state rather than storing duplicated information
- **Clear Dependencies**: Make provider dependencies explicit and minimal

### 4.3 Testing Migration

Implement testing strategies for state management:

```dart
// Provider testing example
testWidgets('measure mode provider updates UI', (tester) async {
  late WidgetRef ref;
  
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, providerRef, child) {
          ref = providerRef;
          return MaterialApp(
            home: MeasureModeButton(),
          );
        },
      ),
    ),
  );
  
  // Initial state
  expect(ref.read(measureModeProvider), isFalse);
  
  // Toggle state
  ref.read(measureModeProvider.notifier).state = true;
  await tester.pump();
  
  // Verify state change
  expect(ref.read(measureModeProvider), isTrue);
});
```

---

## 5. Testing Patterns

### 5.1 Provider Testing

Implement comprehensive testing for provider logic:

#### 5.1.1 Simple Provider Testing

Test simple state providers:

```dart
void main() {
  group('UI Providers', () {
    test('measureModeProvider initial state is false', () {
      final container = ProviderContainer();
      final result = container.read(measureModeProvider);
      expect(result, isFalse);
      container.dispose();
    });
    
    test('measureModeProvider state can be toggled', () {
      final container = ProviderContainer();
      
      // Toggle state
      container.read(measureModeProvider.notifier).state = true;
      expect(container.read(measureModeProvider), isTrue);
      
      container.dispose();
    });
  });
}
```

#### 5.1.2 Complex Provider Testing

Test StateNotifier providers with business logic:

```dart
void main() {
  group('RouteStateNotifier', () {
    test('addPoint increases point count and updates distance', () {
      final container = ProviderContainer();
      final notifier = container.read(routeStateProvider.notifier);
      
      // Add first point
      notifier.addPoint(const LatLng(59.0, 18.0));
      
      var state = container.read(routeStateProvider);
      expect(state.points.length, 1);
      expect(state.totalDistance, 0.0);
      
      // Add second point
      notifier.addPoint(const LatLng(59.1, 18.1));
      
      state = container.read(routeStateProvider);
      expect(state.points.length, 2);
      expect(state.totalDistance, greaterThan(0.0));
      
      container.dispose();
    });
  });
}
```

### 5.2 Widget Testing with Providers

Test widgets that consume providers:

```dart
testWidgets('DistancePanel displays provider state correctly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routeStateProvider.overrideWith((ref) {
          return RouteStateNotifier()..addPoint(const LatLng(59.0, 18.0));
        }),
      ],
      child: const MaterialApp(
        home: DistancePanel(),
      ),
    ),
  );
  
  // Verify UI reflects provider state
  expect(find.text('1 punkt'), findsOneWidget);
});
```

### 5.3 Integration Testing

Test complete workflows with providers:

```dart
testWidgets('complete route creation workflow', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: const MaterialApp(
        home: GravelStreetsMap(),
      ),
    ),
  );
  
  // Enable measure mode
  await tester.tap(find.byIcon(Icons.straighten));
  await tester.pump();
  
  // Add points by tapping map
  await tester.tapAt(const Offset(100, 200));
  await tester.pump();
  
  await tester.tapAt(const Offset(150, 250));
  await tester.pump();
  
  // Verify route state
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GravelStreetsMap)),
  );
  final routeState = container.read(routeStateProvider);
  expect(routeState.points.length, 2);
});
```

---

## 6. Best Practices

### 6.1 Provider Design Guidelines

#### 6.1.1 Provider Naming

Use consistent naming conventions:

```dart
// Good: Descriptive and consistent
final measureModeProvider = StateProvider<bool>((ref) => false);
final routePointsProvider = StateProvider<List<LatLng>>((ref) => []);
final isLoadingRoutesProvider = StateProvider<bool>((ref) => false);

// Avoid: Generic or unclear names
final dataProvider = StateProvider<Object>((ref) => null);
final stateProvider = StateProvider<bool>((ref) => false);
```

#### 6.1.2 State Granularity

Design providers with appropriate granularity:

```dart
// Good: Focused, single-purpose providers
final routePointsProvider = StateProvider<List<LatLng>>((ref) => []);
final loopClosedProvider = StateProvider<bool>((ref) => false);
final editingIndexProvider = StateProvider<int?>((ref) => null);

// Avoid: Overly broad state objects
final everythingProvider = StateProvider<Map<String, dynamic>>((ref) => {});
```

### 6.2 Consumer Widget Patterns

#### 6.2.1 Efficient Consumer Usage

Use appropriate consumer patterns:

```dart
// Good: Use Consumer for specific rebuilds
Consumer(
  builder: (context, ref, child) {
    final measureEnabled = ref.watch(measureModeProvider);
    return IconButton(
      icon: Icon(Icons.straighten),
      color: measureEnabled ? Colors.green : Colors.red,
      onPressed: () => ref.read(measureModeProvider.notifier).state = !measureEnabled,
    );
  },
)

// Good: Use ref.listen for side effects
ref.listen<bool>(measureModeProvider, (previous, next) {
  if (next) {
    // Show measurement instructions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Measurement mode enabled')),
    );
  }
});
```

#### 6.2.2 State Access Patterns

Choose appropriate state access methods:

```dart
// Use ref.watch() for reactive UI updates
Widget build(BuildContext context, WidgetRef ref) {
  final points = ref.watch(routePointsProvider);
  return Text('Points: ${points.length}');
}

// Use ref.read() for one-time access or event handlers
void onTap() {
  final currentPoints = ref.read(routePointsProvider);
  // Process points...
}

// Use ref.listen() for side effects
ref.listen<List<LatLng>>(routePointsProvider, (previous, next) {
  if (next.length > 10) {
    // Show performance warning
  }
});
```

### 6.3 Error Handling

#### 6.3.1 Provider Error Handling

Implement proper error handling in providers:

```dart
final routeDataProvider = FutureProvider<List<SavedRoute>>((ref) async {
  try {
    final service = ref.read(routeServiceProvider);
    return await service.getAllRoutes();
  } catch (error, stackTrace) {
    // Log error
    print('Error loading routes: $error');
    
    // Provide fallback
    return <SavedRoute>[];
  }
});
```

#### 6.3.2 UI Error Handling

Handle provider errors in UI:

```dart
Consumer(
  builder: (context, ref, child) {
    final asyncRoutes = ref.watch(routeDataProvider);
    
    return asyncRoutes.when(
      data: (routes) => RoutesList(routes: routes),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Column(
        children: [
          const Icon(Icons.error, color: Colors.red),
          Text('Error: ${error.toString()}'),
          ElevatedButton(
            onPressed: () => ref.refresh(routeDataProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  },
)
```

### 6.4 Performance Optimization

#### 6.4.1 Provider Optimization

Optimize provider performance:

```dart
// Use select() to prevent unnecessary rebuilds
Consumer(
  builder: (context, ref, child) {
    // Only rebuild when point count changes, not individual points
    final pointCount = ref.watch(routeStateProvider.select((state) => state.points.length));
    return Text('Points: $pointCount');
  },
)

// Use family providers for parameterized state
final routeProvider = StateNotifierProvider.family<RouteNotifier, Route, String>((ref, routeId) {
  return RouteNotifier(routeId);
});
```

#### 6.4.2 Memory Management

Manage provider lifecycle properly:

```dart
// Dispose heavy resources in provider disposal
final heavyComputationProvider = Provider.autoDispose<HeavyService>((ref) {
  final service = HeavyService();
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
```

---

*This document provides comprehensive guidance for Riverpod implementation in the Gravel First application. Refer to the main architecture document for overall system design patterns.*

*Last updated: 2025-01-27*
