# Gravel First – ArchiThis document provides a concise overview of the Gravel First Flutter ## Code Layout

The application has been refactored from a monolithic structure into a clean, organized architecture with separation of concerns:

## Top-level Structure

- `lib/` — application source code
- `test/` — Flutter widget tests
- Platform folders: `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`

## Refactored File Structure

```text
lib/
├── main.dart                    # App entry point, theme, and main map widget (1,459 lines)
├── models/
│   └── saved_route.dart         # Data model for saved routes with JSON serialization
├── services/
│   ├── route_service.dart       # Route management and saved routes business logic
│   ├── location_service.dart    # GPS location handling and permissions
│   └── file_service.dart        # Import/export functionality for GPX and GeoJSON
├── utils/
│   └── coordinate_utils.dart    # Coordinate parsing and formatting utilities
├── widgets/
│   ├── point_marker.dart        # Reusable route point marker component
│   └── distance_panel.dart      # Distance measurement panel with controls
├── screens/
│   └── map_screen.dart          # Alternative map screen implementation (unused)
└── context/
    ├── architecture.md          # This documentation file
    └── roadmap.md              # Feature roadmap and change history
```

## Component Responsibilities

### Core Application (`main.dart`)

- App scaffold, theming, and Material Design configuration
- `GravelStreetsMap` stateful widget containing primary map functionality
- Overpass API integration for fetching gravel road data
- Map interaction handling and state management
- UI layout including AppBar actions and App Drawer
- Map layers: `PolylineLayer` for gravel roads and routes, `MarkerLayer` for points

### Models Layer (`models/`)

- **`saved_route.dart`**: `SavedRoute` data class with JSON serialization
  - Properties: name, points (LatLng[]), loopClosed, savedAt
  - Methods: `toJson()`, `fromJson()` for SharedPreferences storage

### Services Layer (`services/`)

- **`route_service.dart`**: Route management business logic
  - Saved routes CRUD operations with 5-route limit and FIFO removal
  - Distance calculations using latlong2
  - Map centering and bounds fitting
  - Route validation and state management

- **`location_service.dart`**: GPS and location functionality
  - Permission handling and error management
  - Current position acquisition with geolocator
  - Map centering integration
  - User-friendly error messaging

- **`file_service.dart`**: Import/export operations
  - GeoJSON LineString export/import with loop state preservation
  - GPX 1.1 track export/import (trk/trkseg/trkpt structure)
  - File picker and saver integration
  - Format validation and error handling

### Utilities Layer (`utils/`)

- **`coordinate_utils.dart`**: Data processing utilities
  - `extractPolylineCoords()`: Overpass API JSON parsing
  - `formatDistance()`: Human-readable distance formatting (meters/kilometers)
  - Static utility methods for coordinate manipulation

### Widgets Layer (`widgets/`)

- **`point_marker.dart`**: Route point visualization
  - Configurable marker appearance (normal vs editing state)
  - Consistent theming with primary/tertiary color support
  - Compact circular design with shadows and borders

- **`distance_panel.dart`**: Measurement interface
  - Segment and total distance display
  - Action buttons: Undo, Save, Clear
  - Loop toggle functionality
  - Editing state indicators
  - Responsive layout with scrollable segment list

## Architectural Benefits

1. **Separation of Concerns**: Each file has a single, well-defined responsibility
2. **Maintainability**: Code is easier to locate, understand, and modify
3. **Testability**: Services and utilities can be easily unit tested
4. **Reusability**: Components can be reused across different parts of the application
5. **Scalability**: New features can be added without increasing main.dart complexity
6. **Collaboration**: Multiple developers can work on different components simultaneously

## Import Dependencies

The refactored structure maintains clean import relationships:

- `main.dart` imports models, utils, and widgets
- Services are self-contained with minimal cross-dependencies
- Widgets depend only on utils for shared functionality
- Models have no internal dependencies except external packages

## Migration Notes

- Original monolithic file: `main_original_backup.dart` (1,816 lines)
- Refactored main file: `main.dart` (1,459 lines - 20% reduction)
- All functionality preserved with improved organization
- Backward compatibility maintained for saved routes and user data

## Table of Contents

- Overview
- Tech Stack
- System Architecture
- Key Features
- Code Layout
- Data & Tiles
- Measurement Details
- Permissions
- How to Run
- Testing
- Development Notes
- Roadmap
- Change Log

This document provides a concise overview of the Gravel Biking Flutter project: what it does, how it’s organized, the main dependencies, and how to run and test it.

## Overview

A cross‑platform Flutter app that displays a map with gravel roads (queried from OpenStreetMap via Overpass API) and lets you measure custom routes. Import/export routes as GeoJSON/GPX and quickly jump to your GPS position:

- Tap the map to place points (dots).
- Dots are connected with a polyline.
- Per‑segment and total distances are calculated and shown in a corner panel.
- Use the AppBar “Locate me” button to add a marker at your current position.
- Use the Drawer (hamburger menu) to Import/Export GeoJSON and GPX.

## Tech Stack

- Flutter (Dart >= 3.9)
- flutter_map (map rendering; Leaflet-style in Flutter)
- latlong2 (geodesic distance calculations)
- http (fetching gravel road geometry via Overpass API)
- shared_preferences (local storage for saved routes)

Supported platforms (project folders present): Android, iOS, Web, macOS, Linux, Windows.

## System Architecture

Logical components and responsibilities:

- Map UI (flutter_map)
  - Renders tiles, overlays gravel polylines and the measurement polyline/markers.
  - Handles user interactions (map taps, marker taps/long‑press) and forwards map movement events.
- Data Fetcher (Overpass)
  - Issues Overpass queries (http) to retrieve gravel ways for the current visible bounds.
  - Parses JSON off the UI thread (compute) into Polyline models.
  - Debounced viewport-based fetching on map movement (500ms), with tolerance to avoid redundant requests.
- Measurement Manager
  - Manages route points, editing selection, open/closed loop state.
  - Computes per‑segment distances and totals with latlong2.Distance.
- Saved Routes Manager
  - Stores up to 5 named routes locally using SharedPreferences with JSON serialization.
  - Automatic FIFO removal when limit exceeded; auto-centering when routes are loaded.
  - Route data includes name, points array, and save timestamp.
- Import/Export
  - GeoJSON: serialize current route to LineString and save via file_saver; import with file_picker; preserves loop flag when present.
  - GPX: export a GPX 1.1 track (trk/trkseg/trkpt) and import GPX (reads trkpt lat/lon). If the GPX track is explicitly closed (first==last), the app infers loop mode.
- Navigation & Actions
  - AppBar actions: “Locate me” and a green/red measure-mode toggle.
  - App Drawer contains Import/Export groups (GeoJSON, GPX) using ExpansionTiles (closed by default), plus a switch to show/hide the gravel overlay.
  - Map centering: After a successful “Locate me”, the map recenters to your position using a MapController and the most recent zoom.

## Key Features

- Gravel roads overlay fetched from Overpass API (OpenStreetMap data) for the current visible map bounds.
  - Viewport-based refresh: updates gravel overlay when you pan/zoom (debounced).
- Tap‑to‑measure routes:
  - Drop markers on tap; a polyline connects them in order.
  - Segment distances (between consecutive points) and total distance.
  - Undo last point and Clear all.
  - Editable points: tap a marker to select, tap map to move; long‑press to delete.
  - Close/Open loop: connect last→first, adds a loop segment to the list and total.
- Saved Routes: Save up to 5 named routes locally on device.
  - Routes stored with SharedPreferences using JSON serialization.
  - Quick-save button in distance panel (bookmark icon).
  - Full management in drawer: view all saved routes, load with auto-centering, delete individual routes.
  - FIFO removal: oldest routes automatically removed when limit exceeded.
- Import/Export (GeoJSON): export current route as GeoJSON; import a GeoJSON LineString to restore.
- Import/Export (GPX): export as GPX 1.1 track and import GPX files.
- Locate me (GPS): request permissions and place a marker at your current location.
  - After locating, the map recenters to your position (instant move; animation can be added later).
- Tiles: Unified OpenStreetMap standard tiles for both light and dark themes.

## Code Layout

Top-level folders of interest:

- `lib/` — application source (entry point: `lib/main.dart`).
- `test/` — Flutter widget tests (`test/widget_test.dart`).
- Platform folders: `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`.

Important files:

- `lib/main.dart`
  - App scaffold and theming.
  - `GravelStreetsMap` stateful widget.
  - Overpass fetch to retrieve gravel street polylines for the current viewport; JSON parsing in `compute`.
  - Map interaction: `MapOptions(onTap: ...)` to add/move points; `onMapEvent` debounced to fetch data; `MapController` to track last zoom and recenter on locate.
  - UI: AppBar actions (Locate me, measure-mode toggle); App Drawer with Import/Export (GeoJSON/GPX) using ExpansionTiles.
  - Layers: `PolylineLayer` for gravel and measured route; `MarkerLayer` for route points and a “my position” marker when available.
- `pubspec.yaml`
  - Declares dependencies: `flutter_map`, `latlong2`, `http`, etc.

## Data & Tiles

- Data source: Overpass API (`https://overpass-api.de/api/interpreter`) with a query for ways where `surface=gravel` and `highway` among a selected set within the current visible bounding box. Initial fetch uses a Stockholm area bbox.
- Tile server:
  - OpenStreetMap standard tiles: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (used for both themes)

Tile usage note: If you plan production use, review provider terms. OSM’s public tile servers have usage policies and are not intended for high‑traffic apps. Consider a dedicated tile provider and set a clear User-Agent.

## Measurement Details

- Distances computed with `latlong2`’s `Distance.as(LengthUnit.Meter, p1, p2)`, using great‑circle/geodesic approximations.
- Display formatting:
  - Under ~950 m: show meters (e.g., `734 m`).
  - Otherwise: show kilometers with 1–2 decimals (e.g., `2.4 km`, `7.85 km`).
- Segment list shows distances between sequential points; total is a running sum.

## Loop measurement

- When 3 or more points are placed, a “Close loop / Open loop” button appears in the distance panel.
- Closing the loop connects the last point back to the first, adds a final “Loop segment” to the list, and updates the total.
- Adding a new point automatically re‑opens the loop (so you don’t accidentally keep closing it while extending the route).
- Undo removes the last point and recalculates; if fewer than 3 points remain, loop mode is disabled.

## Permissions

- Location: Uses `geolocator` to request/check permissions at runtime and read current position.
  - iOS: Add NSLocationWhenInUseUsageDescription to `Info.plist`.
  - Android: Ensure location permissions in AndroidManifest (coordinated by `geolocator` setup); location services must be enabled.

## How to Run

Prerequisites: Flutter SDK installed.

Optional commands to get started:

```bash
flutter pub get
flutter run
```

## Testing

Optional test commands:

```bash
flutter test -r expanded
```

A basic widget test is included that ensures the app builds and the distance panel hint is visible initially.

## Development Notes

- Overpass query is viewport-based and debounced; parsing runs on a background isolate via `compute`.
- Gravel polylines use a fixed brown color.
- For tile usage in production, configure a proper provider, keys, and a descriptive `userAgentPackageName`.
- Route point markers are compact circular dots without numeric labels; the selected point is highlighted.
- Version/build watermark: Version auto-loaded from pubspec.yaml via package_info_plus; build number from CI dart-defines.
- UI contrast: Drawer icons use onSurface color; locate me button uses onSecondaryContainer for proper visibility.
- Drawer overlays: Two switches (Overpass enabled, TRV NVDB disabled/prepared) for different gravel data sources.

## Roadmap

The roadmap lives alongside this document for clarity:

- See: `lib/context/roadmap.md`

---
Last updated: 2025‑08‑25

## Change Log

- 2025‑08‑25: **Major Refactoring**: Restructured codebase from monolithic 1,816-line main.dart into organized architecture:
  - Created `models/saved_route.dart` for data structures
  - Added `services/` layer: `route_service.dart`, `location_service.dart`, `file_service.dart`
  - Extracted `utils/coordinate_utils.dart` for utility functions
  - Created reusable `widgets/`: `point_marker.dart`, `distance_panel.dart`
  - Reduced main.dart to 1,459 lines (20% reduction) while preserving all functionality
  - Improved maintainability, testability, and code organization
- 2025‑08‑25: Added Saved Routes feature: save up to 5 named routes locally using SharedPreferences with JSON serialization. Quick-save button in distance panel, full management in drawer with auto-centering when loading routes.
- 2025‑08‑24: Added GeoJSON import/export (file_picker, file_saver). Initially in distance panel; later moved to Drawer.
- 2025‑08‑24: Added GPX import/export (xml, file_picker/file_saver). Loop inferred if first==last; actions live in Drawer.
- 2025‑08‑24: Editable points (tap‑to‑move, long‑press delete) and editing banner/highlight.
- 2025‑08‑24: Implemented loop close/open with extra loop segment reporting.
- 2025‑08‑24: Viewport-based Overpass fetching with 500ms debounce and off‑UI parsing.
- 2025‑08‑24: AppBar “Locate me” via geolocator; added my-position marker.
- 2025‑08‑24: Import/Export moved to a Drawer (hamburger) with ExpansionTiles (GeoJSON, GPX), initially expanded. Improved contrast and discoverability.
- 2025‑08‑24: Import/Export moved to a Drawer (hamburger) with ExpansionTiles (GeoJSON, GPX), default closed. Added Drawer switch to toggle gravel overlay.
- 2025‑08‑24: Measure-mode toggle styled green (on) / red (off). Clarified distance panel hint text.
- 2025‑08‑24: On “Locate me”, recenter the map to current location using MapController (instant move, uses last zoom).
- 2025‑08‑24: Standardized tiles to OpenStreetMap for both themes; reduced point marker size and removed numeric labels.
- 2025‑08‑24: Added bottom-left version/build watermark (values from CI via dart-defines).
- 2025‑08‑25: Automatic version detection from pubspec.yaml using package_info_plus; version/build shown in drawer footer and map watermark.
- 2025‑08‑25: Fixed icon contrast: drawer icons use onSurface color, locate me button uses onSecondaryContainer.
- 2025‑08‑25: Added disabled TRV NVDB gravel overlay switch in drawer, prepared for future Trafikverket integration.
