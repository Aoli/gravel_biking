# Architecture

This document provides a comprehensive overview of the Gravel First Flutter application architecture, codebase organization, and technical implementation details.

## Overview

A cross‑platform Flutter app that displays gravel roads from OpenStreetMap and enables interactive route measurement. The application has been refactored from a monolithic structure into a clean, organized architecture with separation of concerns.

## Tech Stack

- **Framework**: Flutter (Dart >= 3.9)
- **Map Rendering**: flutter_map (Leaflet-style mapping)
- **Geospatial**: latlong2 (geodesic distance calculations)
- **Networking**: http (Overpass API queries)
- **Storage**: shared_preferences (local route persistence)
- **File Operations**: file_picker, file_saver (import/export)
- **Location**: geolocator (GPS positioning)
- **Parsing**: xml (GPX file support)

## Refactored File Structure

The application has been restructured from a monolithic 1,816-line main.dart into organized layers:

```text
lib/
├── main.dart                    # App entry point and main map widget (1,465 lines)
├── models/
│   └── saved_route.dart         # Data model for saved routes with JSON serialization
├── services/
│   ├── route_service.dart       # Route management and business logic
│   ├── location_service.dart    # GPS location handling and permissions
│   └── file_service.dart        # Import/export functionality (GPX/GeoJSON)
├── utils/
│   └── coordinate_utils.dart    # Coordinate parsing and formatting utilities
└── widgets/
    ├── point_marker.dart        # Reusable route point marker component
    └── distance_panel.dart      # Distance measurement panel with controls
```

## Component Responsibilities

### Core Application (`main.dart`)
- App scaffold, theming, and Material Design configuration
- `GravelStreetsMap` stateful widget with primary map functionality
- Overpass API integration for gravel road data fetching
- Map interaction handling and state management
- UI layout including AppBar actions and drawer
- Map layers: PolylineLayer for roads/routes, MarkerLayer for points

### Models Layer (`models/`)
- **`SavedRoute`**: Data class with JSON serialization
  - Properties: name, points (LatLng[]), loopClosed, savedAt
  - Methods: `toJson()`, `fromJson()` for SharedPreferences storage

### Services Layer (`services/`)
- **`RouteService`**: Business logic for route management
  - Saved routes CRUD with 5-route limit and FIFO removal
  - Distance calculations and map centering
- **`LocationService`**: GPS and location functionality
  - Permission handling and current position acquisition
- **`FileService`**: Import/export operations
  - GeoJSON LineString and GPX 1.1 support

### Utilities Layer (`utils/`)
- **`CoordinateUtils`**: Data processing utilities
  - Overpass API JSON parsing
  - Distance formatting (meters/kilometers)

### Widgets Layer (`widgets/`)
- **`PointMarker`**: Route point visualization with theming
- **`DistancePanel`**: Measurement interface with controls

## Key Features

### Icon System
- **Cross-platform compatibility**: Uses Google Material Icons with CDN fallback
- **Outlined icon variants**: Enhanced visibility and contrast across all platforms
- **Consistent theming**: All icons properly themed for light/dark modes
- **Web optimization**: Google Fonts integration for web app compatibility

### Measurement System
- Tap-to-measure with toggle mode (green/red indicator)
- Per-segment and total distance calculations
- Editable points: tap to select and move, long-press to delete
- Loop closure support with additional segment calculation

### Saved Routes
- Store up to 5 named routes locally using SharedPreferences
- FIFO removal when limit exceeded
- Auto-centering when routes are loaded
- Quick-save from distance panel, full management in drawer

### Import/Export
- **GeoJSON**: LineString format with loop state preservation
- **GPX**: GPX 1.1 track format (trk/trkseg/trkpt structure)
- File operations via system file picker/saver

### Location Services
- GPS positioning with permission handling
- "Locate me" functionality with map centering
- Error handling for disabled services or denied permissions

## Data Sources

- **Gravel Roads**: Overpass API queries for OpenStreetMap data
  - Viewport-based fetching with 500ms debounce
  - Background parsing using `compute` for performance
- **Map Tiles**: OpenStreetMap standard tiles for all themes

## Architectural Benefits

1. **Separation of Concerns**: Each component has a single responsibility
2. **Maintainability**: Code is easier to locate, understand, and modify
3. **Testability**: Services and utilities can be unit tested independently
4. **Reusability**: Components can be reused across the application
5. **Scalability**: New features can be added without complexity growth
6. **Collaboration**: Multiple developers can work on different components

## Migration Notes

- **Original**: monolithic `main_original_backup.dart` (1,816 lines)
- **Refactored**: organized `main.dart` (1,465 lines - 19% reduction)
- **Cleanup**: Removed unused refactoring artifacts and resolved all analysis issues
- **Compatibility**: All functionality preserved, user data maintained
- **Dependencies**: Clean import relationships with minimal cross-dependencies

## Development Notes

- **Performance**: JSON parsing runs on background isolates
- **UI**: Material 3 theming with Swedish localization
- **Testing**: Widget tests included for core functionality
- **Build**: Version/build watermark from pubspec.yaml and CI

## Change Log

- **2025‑08‑25**: Code Quality Cleanup - Resolved all Flutter analysis issues, removed unnecessary imports, added missing curly braces, cleaned up unused refactoring artifacts
- **2025‑08‑25**: Icon Visibility Improvements - Enhanced cross-platform compatibility with Google Material Icons, outlined variants for better contrast, and consistent theming
- **2025‑08‑25**: Major Refactoring - Restructured from monolithic to layered architecture (19% code reduction)
- **2025‑08‑25**: Saved Routes - Local storage for up to 5 named routes with SharedPreferences
- **2025‑08‑24**: Core Features - GPX/GeoJSON import/export, editable points, loop support, GPS integration

---
Last updated: 2025‑08‑25
