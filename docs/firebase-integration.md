# Firebase Integration Guide

## Overview

This document provides comprehensive guidance for the Firebase Cloud Storage and Authentication integration in Gravel First. The implementation provides automatic authentication with Firestore route storage supporting public/private visibility controls.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Authentication Service](#authentication-service)
3. [Firestore Route Service](#firestore-route-service)
4. [Hybrid Storage Service](#hybrid-storage-service)
5. [Enhanced Data Models](#enhanced-data-models)
6. [Provider Integration](#provider-integration)
7. [User Interface Updates](#user-interface-updates)
8. [Configuration](#configuration)
9. [Testing Strategy](#testing-strategy)

## Architecture Overview

### Design Principles

- **Offline-First**: Routes always save locally first, then sync to cloud when possible
- **Seamless Authentication**: Anonymous authentication happens automatically in background
- **Progressive Enhancement**: App works fully offline, gains cloud features when authenticated
- **Zero Blocking Operations**: UI never blocks waiting for cloud operations
- **Graceful Degradation**: Cloud sync failures don't break core functionality

### Service Hierarchy

```
SyncedRouteService (Hybrid Layer)
├── RouteService (Local Hive Storage)
└── FirestoreRouteService (Cloud Storage)
    └── AuthService (Firebase Authentication)
```

## Authentication Service

### Implementation: `lib/services/auth_service.dart`

The `AuthService` provides automatic Firebase Authentication with anonymous sign-in:

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Automatic initialization with network and Firebase checks
  Future<UserCredential?> initialize() async {
    try {
      // Check network connectivity first
      if (!await _checkNetworkAndFirebase()) {
        debugPrint('$_logPrefix Network or Firebase not available - skipping authentication');
        return null;
      }

      // Attempt anonymous sign-in
      return await signInAnonymously();
    } catch (e) {
      debugPrint('$_logPrefix Authentication initialization failed: $e');
      return null;
    }
  }

  /// Anonymous sign-in for seamless user experience
  Future<UserCredential?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    debugPrint('$_logPrefix ✅ Anonymous sign-in successful: ${result.user?.uid}');
    return result;
  }
}
```

### Key Features

- **Automatic Initialization**: Called during app startup in `_initializeServices()`
- **Network Validation**: Checks connectivity before attempting authentication
- **Anonymous Authentication**: No user registration required - seamless experience
- **Error Resilience**: Graceful handling of network/Firebase failures
- **State Monitoring**: Provides `authStateChanges` stream for reactive UI updates

## Firestore Route Service

### Implementation: `lib/services/firestore_route_service.dart`

The `FirestoreRouteService` handles all cloud database operations:

```dart
class FirestoreRouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Save route to Firestore with user ownership and visibility
  Future<String> saveRoute(SavedRoute route, String userId) async {
    final docRef = await _firestore.collection('routes').add({
      ...route.toFirestore(),
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get all routes accessible to user (private routes + public routes)
  Future<List<SavedRoute>> getAllAccessibleRoutes(String userId) async {
    // Private routes for this user
    final privateQuery = _firestore.collection('routes')
        .where('userId', isEqualTo: userId)
        .where('isPublic', isEqualTo: false);
    
    // All public routes
    final publicQuery = _firestore.collection('routes')
        .where('isPublic', isEqualTo: true);
    
    // Execute both queries concurrently
    final results = await Future.wait([
      privateQuery.get(),
      publicQuery.get(),
    ]);
    
    // Combine and deduplicate results
    final routes = <String, SavedRoute>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        final route = SavedRoute.fromFirestore(doc.data(), doc.id);
        routes[route.firestoreId!] = route;
      }
    }
    
    return routes.values.toList();
  }
}
```

### Cloud Operations

- **Route Storage**: Full CRUD operations with server timestamps
- **Visibility Control**: Separate queries for private (user-specific) and public routes
- **User Ownership**: Routes linked to users via `userId` field
- **Search Functionality**: Text search across public routes
- **Real-time Updates**: Stream-based APIs for reactive UI updates
- **Batch Operations**: Efficient bulk operations for large route sets

## Hybrid Storage Service

### Implementation: `lib/services/synced_route_service.dart`

The `SyncedRouteService` combines local and cloud storage:

```dart
class SyncedRouteService {
  final RouteService _localService;
  final FirestoreRouteService _cloudService;
  final AuthService _authService;

  /// Save route with automatic cloud sync
  Future<void> saveCurrentRoute(String name, List<LatLng> points, {bool isPublic = false}) async {
    // Create route with metadata
    final route = SavedRoute(
      name: name,
      points: points,
      isPublic: isPublic,
      userId: _authService.userId,
      createdAt: DateTime.now(),
      lastSynced: null, // Will be set after cloud sync
    );

    // Always save locally first (offline-first)
    await _localService.saveRoute(route);

    // Attempt cloud sync if authenticated
    if (_authService.isSignedIn) {
      try {
        final firestoreId = await _cloudService.saveRoute(route, _authService.userId!);
        
        // Update local route with cloud reference
        final syncedRoute = route.copyWith(
          firestoreId: firestoreId,
          lastSynced: DateTime.now(),
        );
        await _localService.updateRoute(name, syncedRoute);
        
        debugPrint('✅ Route synced to cloud: $firestoreId');
      } catch (e) {
        debugPrint('❌ Cloud sync failed, route remains local: $e');
        // Route is still saved locally - no data loss
      }
    }
  }

  /// Load all accessible routes (local + cloud with deduplication)
  Future<List<SavedRoute>> loadAllRoutes() async {
    final localRoutes = await _localService.loadRoutes();
    
    if (!_authService.isSignedIn) {
      return localRoutes; // Return only local routes if not authenticated
    }

    try {
      final cloudRoutes = await _cloudService.getAllAccessibleRoutes(_authService.userId!);
      
      // Merge and deduplicate (cloud routes take precedence for synced items)
      final mergedRoutes = <String, SavedRoute>{};
      
      // Add local routes first
      for (final route in localRoutes) {
        mergedRoutes[route.name] = route;
      }
      
      // Add cloud routes (overwrites local if same name and has firestoreId)
      for (final route in cloudRoutes) {
        if (route.firestoreId != null) {
          mergedRoutes[route.name] = route;
        }
      }
      
      return mergedRoutes.values.toList();
    } catch (e) {
      debugPrint('❌ Failed to load cloud routes, returning local only: $e');
      return localRoutes; // Graceful degradation
    }
  }
}
```

### Sync Strategy

- **Offline-First**: Local storage is primary, cloud is enhancement
- **Automatic Sync**: Cloud sync happens transparently for authenticated users
- **Deduplication**: Smart merging of local and cloud routes based on `firestoreId`
- **Conflict Resolution**: Cloud routes take precedence for synced items
- **Error Recovery**: Network failures don't affect local functionality
- **Background Sync**: Future enhancement for periodic sync operations

## Enhanced Data Models

### SavedRoute Model Updates

Added fields to support cloud storage and visibility:

```dart
@HiveType(typeId: 0)
class SavedRoute extends HiveObject {
  @HiveField(0)
  final String name;
  
  @HiveField(1)
  final List<LatLng> points;
  
  @HiveField(2)
  final DateTime createdAt;
  
  @HiveField(3)
  final bool isLoop;
  
  @HiveField(4)
  final double distance;
  
  // New fields for cloud integration
  @HiveField(5)
  final bool isPublic;
  
  @HiveField(6)
  final String? userId;
  
  @HiveField(7)
  final String? firestoreId;
  
  @HiveField(8)
  final DateTime? lastSynced;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'isLoop': isLoop,
    'distance': distance,
    'isPublic': isPublic,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// Create from Firestore document
  static SavedRoute fromFirestore(Map<String, dynamic> data, String id) {
    final points = (data['points'] as List)
        .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
        .toList();
    
    return SavedRoute(
      name: data['name'] as String,
      points: points,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isLoop: data['isLoop'] as bool? ?? false,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      isPublic: data['isPublic'] as bool? ?? false,
      userId: data['userId'] as String?,
      firestoreId: id,
      lastSynced: DateTime.now(),
    );
  }
}
```

### Field Descriptions

- **`isPublic`**: Controls route visibility (true = public, false = private)
- **`userId`**: Links routes to their owners for access control
- **`firestoreId`**: Cloud storage reference for synced routes
- **`lastSynced`**: Timestamp of last successful cloud synchronization

## Provider Integration

### Riverpod Providers: `lib/providers/service_providers.dart`

```dart
// Authentication providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authInitializationProvider = FutureProvider<UserCredential?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.initialize();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.authStateChanges;
});

final isSignedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Cloud storage providers
final firestoreRouteServiceProvider = Provider<FirestoreRouteService>((ref) => FirestoreRouteService());

final syncedRouteServiceProvider = Provider<SyncedRouteService>((ref) {
  final routeService = ref.read(routeServiceProvider);
  final firestoreService = ref.read(firestoreRouteServiceProvider);
  final authService = ref.read(authServiceProvider);
  return SyncedRouteService(routeService, firestoreService, authService);
});

// Route data providers
final allAccessibleRoutesProvider = FutureProvider<List<SavedRoute>>((ref) {
  final syncedService = ref.read(syncedRouteServiceProvider);
  return syncedService.loadAllRoutes();
});
```

### Provider Dependencies

- **Authentication Flow**: `authInitializationProvider` → `authStateProvider` → `isSignedInProvider`
- **Service Composition**: Individual services combined into `syncedRouteServiceProvider`
- **Data Loading**: `allAccessibleRoutesProvider` provides unified route list
- **Reactive Updates**: Authentication state changes trigger UI rebuilds

## User Interface Updates

### Save Route Dialog: `lib/widgets/save_route_dialog.dart`

Enhanced with visibility controls for authenticated users:

```dart
// Public/Private visibility option (only for authenticated users)
if (widget.isAuthenticated) ...[
  const SizedBox(height: 16),
  Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Synlighet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: false,
                groupValue: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value ?? false),
              ),
              const Text('🔒 Privat'),
              const Expanded(
                child: Text(
                  'Bara du kan se denna rutt',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value ?? false),
              ),
              const Text('🌐 Offentlig'),
              const Expanded(
                child: Text(
                  'Alla användare kan se denna rutt',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
] else ...[
  // Information for non-authenticated users
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      border: Border.all(color: Colors.blue.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Colors.blue, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Rutten sparas lokalt på din enhet. Logga in för molnsynkronisering och delning.',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
      ],
    ),
  ),
],
```

### UI Features

- **Conditional Visibility Controls**: Only shown for authenticated users
- **Clear Visual Design**: Radio buttons with descriptive text and icons
- **Information Messages**: Helpful guidance for non-authenticated users
- **Swedish Localization**: All text in Swedish for consistent UX
- **Loading States**: Visual feedback during save operations

## Configuration

### Firebase Setup

1. **Firebase Project**: Create project with Authentication and Firestore enabled
2. **Anonymous Authentication**: Enable in Firebase Console
3. **Firestore Rules**: Configure security rules for route access control
4. **Platform Configuration**: Add configuration files for each platform

### Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /routes/{routeId} {
      // Allow read for public routes or user's own routes
      allow read: if resource.data.isPublic == true 
                  || resource.data.userId == request.auth.uid;
      
      // Allow write only for authenticated users on their own routes
      allow create, update: if request.auth != null 
                           && resource.data.userId == request.auth.uid;
      
      // Allow delete only for route owner
      allow delete: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
    }
  }
}
```

### Environment Configuration

Add Firebase configuration to `env.local.json` if needed for different environments.

## Testing Strategy

### Unit Tests

- **AuthService**: Test authentication flows, network checks, error handling
- **FirestoreRouteService**: Mock Firestore operations, test CRUD functionality  
- **SyncedRouteService**: Test offline/online scenarios, sync logic, error recovery
- **SavedRoute Model**: Test serialization/deserialization, field validation

### Integration Tests

- **End-to-End Flow**: Create route → Save → Sync → Load → Verify visibility
- **Network Scenarios**: Test offline creation, online sync, network failures
- **Authentication States**: Test authenticated vs unauthenticated user flows
- **Route Visibility**: Verify public/private access controls work correctly

### Test Files

- `test/unit/auth_service_test.dart` - Authentication service tests
- `test/unit/firestore_route_service_test.dart` - Cloud storage tests  
- `test/unit/synced_route_service_test.dart` - Hybrid service tests
- `test/integration/firebase_flow_test.dart` - Full integration tests

## Benefits

### User Benefits

- **Seamless Experience**: No sign-up required, automatic cloud backup
- **Data Security**: Routes backed up to cloud, available across devices
- **Sharing Capability**: Choose to share routes publicly or keep private
- **Offline Functionality**: App works fully offline, syncs when connected
- **Zero Wait Time**: Routes save instantly, cloud sync happens in background

### Technical Benefits

- **Scalable Architecture**: Clean separation of concerns, easily extensible
- **Robust Error Handling**: Graceful degradation when cloud services unavailable
- **Performance Optimized**: Offline-first reduces latency, background sync
- **Maintainable Code**: Clear service boundaries, comprehensive documentation
- **Future-Ready**: Architecture supports additional cloud features easily

## Future Enhancements

### Potential Features

- **Real-time Collaboration**: Multiple users editing shared routes
- **Route Comments**: Community feedback on public routes
- **Route Categories**: Tagging and filtering by difficulty, terrain type
- **Social Features**: User profiles, following favorite route creators
- **Advanced Search**: Geographic search, distance filters, popularity sorting
- **Offline Maps**: Cache map tiles for areas with saved routes
- **Route Analytics**: Track usage, popularity metrics for public routes

### Technical Improvements

- **Background Sync**: Periodic synchronization when app is backgrounded  
- **Conflict Resolution**: Handle simultaneous edits to same route
- **Incremental Sync**: Only sync changed data to reduce bandwidth
- **Image Support**: Add photos to routes, store in Firebase Storage
- **Push Notifications**: Notify when shared routes are updated
- **Performance Monitoring**: Firebase Performance and Crashlytics integration

## Conclusion

The Firebase integration provides a robust, user-friendly cloud storage solution while maintaining the app's core offline-first philosophy. The implementation prioritizes user experience with automatic authentication and seamless synchronization, while providing comprehensive error handling and graceful degradation for network-limited scenarios.

The modular architecture makes it easy to extend functionality and add new cloud-based features in the future, while the comprehensive testing strategy ensures reliability across different usage scenarios.
