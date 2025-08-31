# Firebase Integration Guide

## Overview

This document explains the Firebase Authentication and Firestore integration for Gravel First. It covers offline-first sync, route visibility, real-time streams, testing with a cloud abstraction, and provider wiring.

### Table of Contents

1. [Architecture Overview](#architecture-overview)
1. [Authentication Service](#authentication-service)
1. [Firestore Route Service](#firestore-route-service)
1. [Hybrid Storage Service](#hybrid-storage-service)
1. [Routes Streaming](#routes-streaming)
1. [Abstraction for Testability](#abstraction-for-testability)
1. [Enhanced Data Models](#enhanced-data-models)
1. [Provider Integration](#provider-integration)
1. [User Interface Updates](#user-interface-updates)
1. [Configuration](#configuration)
1. [Testing Strategy](#testing-strategy)
1. [Benefits](#benefits)
1. [Future Enhancements](#future-enhancements)
1. [Changelog](#changelog)

## Architecture Overview

### Service Hierarchy

```text
└── RouteCloudService (Cloud abstraction)
    ├── FirestoreRouteService (production)
    └── AuthService (Firebase Authentication)

SyncedRouteService (composition)
└── RouteService (local/Hive) + RouteCloudService + AuthService
```

Key principles:

- Offline-first: save locally, then sync to cloud
- Anonymous auth: runs in background for seamless UX
- Resilience: failures are logged; local functionality remains

## Authentication Service

Implementation: `lib/services/auth_service.dart`

- Initialize with network/Firebase availability checks
- Use anonymous sign-in; expose `authStateChanges`
- Never block UI on failures; continue offline

## Firestore Route Service

Implementation: `lib/services/firestore_route_service.dart`

Responsibilities:

- CRUD for routes with server timestamps
- Visibility: `isPublic` plus `userId` ownership
- Queries: user-private, all-public, search
- Streams: private + public real-time streams

## Hybrid Storage Service

Implementation: `lib/services/synced_route_service.dart`

- Compose local RouteService + RouteCloudService + AuthService
- Save: local-first; then cloud if signed in
- Load: merge cloud+local with dedupe on `firestoreId`
- Errors: fall back to local data

## Routes Streaming

Expose two Firestore streams—one for private routes (owner only) and one for all public routes—merge them, dedupe by `firestoreId`, then sort by `savedAt` (fallback `createdAt`) descending for UI.

```text
   [streamUserRoutes(uid)]      [streamPublicRoutes()]
              \\                        /
               \\                      /
                \\    merge + dedupe  /
                 \\__________________/
                         |
               sort by savedAt desc
                         |
                  routesStream
```

Contract:

- Deduplication key: `firestoreId`
- Sort order: newest first by `savedAt` or fallback `createdAt`
- Error mode: if one stream errors, continue with the other and log
- Tabs mapping: Private (owner-only) and Public (all users)

## Abstraction for Testability

Introduce `RouteCloudService` to decouple Firebase from business logic. In tests, inject an in-memory fake to validate autosave create/overwrite without Firebase init.

Benefits:

- Firebase-free unit tests; deterministic behavior
- Production remains wired to Firestore via DI

## Enhanced Data Models

SavedRoute adds cloud fields for visibility and sync:

- `isPublic` (bool)
- `userId` (String?)
- `firestoreId` (String?)
- `lastSynced` (DateTime?)

Include `toFirestore()` and `fromFirestore()` for serialization.

## Provider Integration

Implementation: `lib/providers/service_providers.dart`

```dart
// Cloud service abstraction bound to Firestore in production
final cloudRouteServiceProvider = Provider<RouteCloudService>(
  (ref) => FirestoreRouteService(),
);

// Synced service composes local + cloud + auth
final syncedRouteServiceProvider = Provider<SyncedRouteService>((ref) {
  final routeService = ref.read(routeServiceProvider);
  final cloudService = ref.read(cloudRouteServiceProvider);
  final authService = ref.read(authServiceProvider);
  return SyncedRouteService(routeService, cloudService, authService);
});
```

## User Interface Updates

- Save dialog shows Public/Private when authenticated
- Non-authenticated users see local-only info message
- Swedish localization preserved

## Configuration

- Enable Anonymous Auth in Firebase Console
- Configure Firestore security rules (owner read/write; public read)
- Add platform-specific Firebase configs

## Testing Strategy

- Unit: AuthService, FirestoreRouteService (mocked), SyncedRouteService, SavedRoute model
- Integration: end-to-end save/sync/load with visibility
- Network/auth scenarios: offline creation, later sync

## Benefits

User:

- Seamless backup, optional sharing, offline-ready

Technical:

- Scalable, maintainable, resilient; clear boundaries and DI

## Future Enhancements

- Background sync; conflict resolution; incremental sync
- Comments, categories, social, search, offline maps, analytics

## Changelog

- 2025-08-31: Normalized Markdown, added routes streaming section, clarified DI providers
