# Gravel First – Architecture & Implementation Guide

This document provides comprehensive architecture guidelines and implementation directives for the Gravel First Flutter application. Follow these patterns to maintain code quality and consistency.

## Implementation Overview

Build a cross‑platform Flutter app that displays gravel roads from OpenStreetMap and enables interactive route measurement. Structure the application using a clean, layered architecture with separation of concerns.

## Required Tech Stack

Use these specific technologies and versions:

- **Framework**: Flutter (Dart >= 3.9)
- **Map Rendering**: flutter_map (Leaflet-style mapping)
- **Geospatial**: latlong2 (geodesic distance calculations)
- **Networking**: http (Overpass API queries)
- **Storage**: shared_preferences (local route persistence)
- **File Operations**: file_picker, file_saver (import/export)
- **Location**: geolocator (GPS positioning)
- **Parsing**: xml (GPX file support)

## Mandatory File Structure

Organize the application using this layered structure:

```text
lib/
├── main.dart                    # App entry point and main map widget (1,459 lines)
├── models/
│   └── saved_route.dart         # Data model for saved routes with JSON serialization
├── services/
│   ├── route_service.dart       # Route management and business logic
│   ├── location_service.dart    # GPS location handling and permissions
│   └── file_service.dart        # Import/export functionality (GPX/GeoJSON)
├── utils/
│   └── coordinate_utils.dart    # Coordinate parsing and formatting utilities
├── widgets/
│   ├── point_marker.dart        # Reusable route point marker component
│   └── distance_panel.dart      # Distance measurement panel with controls
├── screens/
│   └── map_screen.dart          # Alternative map screen implementation (unused)
└── context/
    └── roadmap.md              # Feature roadmap and change history
```

## Component Implementation Requirements

### Core Application (`main.dart`)

Implement the main application file with these responsibilities:

- Configure app scaffold, theming, and Material Design components
- Create `GravelStreetsMap` stateful widget containing primary map functionality
- Integrate Overpass API for gravel road data fetching
- Handle all map interactions and state management
- Structure UI layout including AppBar actions and drawer
- Render map layers: PolylineLayer for roads/routes, MarkerLayer for points

### Models Layer (`models/`)

Create data models following these patterns:

- **`SavedRoute`**: Implement data class with JSON serialization
  - Define properties: name, points (LatLng[]), loopClosed, savedAt
  - Implement methods: `toJson()`, `fromJson()` for SharedPreferences storage

### Services Layer (`services/`)

Build business logic services with these specifications:

- **`RouteService`**: Implement route management business logic
  - Handle saved routes CRUD with 5-route limit and FIFO removal
  - Calculate distances and map centering operations
  - Validate routes and manage state transitions
- **`LocationService`**: Implement GPS and location functionality
  - Handle permission requests and error management
  - Acquire current position using geolocator
  - Integrate map centering and provide user-friendly error messaging
- **`FileService`**: Build import/export operations
  - Support GeoJSON LineString and GPX 1.1 formats
  - Integrate file picker and saver functionality

### Utilities Layer (`utils/`)

Create utility functions with these capabilities:

- **`CoordinateUtils`**: Build data processing utilities
  - Parse Overpass API JSON responses
  - Format distances for human readability (meters/kilometers)

### Widgets Layer (`widgets/`)

Build reusable UI components following these specifications:

- **`PointMarker`**: Implement route point visualization
  - Configure marker appearance for normal and editing states
  - Apply consistent theming with primary/tertiary color support
- **`DistancePanel`**: Create measurement interface
  - Display segment and total distance calculations
  - Provide action buttons: Undo, Save, Clear, Loop toggle
  - Implement responsive layout with scrollable segment list

## Feature Implementation Requirements

### Icon System

Implement cross-platform icon compatibility:

- Use Google Material Icons with comprehensive CDN integration
- Apply filled icon variants for universal platform support
- Configure multiple font format preloading (WOFF2, WOFF)
- Implement enhanced Android WebView compatibility:
  - Multiple fallback font families
  - WebKit-specific rendering optimizations
  - Font loading verification with timeout fallbacks
- Set consistent theming for light/dark modes with platform-specific color settings
- Use JavaScript font loading API with error handling and console logging

### Measurement System

Build the measurement interface with these features:

- Implement tap-to-measure with toggle mode (green/red indicator)
- Calculate per-segment and total distances using geodesic algorithms
- Enable editable points: tap to select and move, long-press to delete
- Support loop closure with additional segment calculation

### Saved Routes

Create local route persistence system:

- Store up to 5 named routes using SharedPreferences
- Implement FIFO removal when limit is exceeded
- Enable auto-centering when routes are loaded
- Provide quick-save from distance panel and full management in drawer

### File Operations

Support file operations for route data:

- **GeoJSON**: Implement LineString format with loop state preservation
- **GPX**: Support GPX 1.1 track format (trk/trkseg/trkpt structure)
- **Cross-platform file handling**: Use conditional platform logic
  - Web: Direct FileSaver API for browser downloads
  - iOS/Android: Use path_provider + FileSaver for native file system access
- **iOS Compatibility**: Implement path_provider for proper iOS file system integration
- **Error Handling**: Provide fallback behavior and user feedback

### Location Services

Implement GPS positioning capabilities:

- Handle GPS positioning with proper permission handling
- Enable "Locate me" functionality with map centering
- Provide error handling for disabled services or denied permissions

## System Architecture

Logical components and responsibilities:

- **Map UI** (flutter_map): Renders tiles, overlays gravel polylines and measurement polyline/markers
- **Data Fetcher** (Overpass): Viewport-based fetching with 500ms debounce, JSON parsing off UI thread
- **Measurement Manager**: Route points, editing selection, distance calculations
- **Saved Routes Manager**: Local storage with SharedPreferences, automatic FIFO management
- **Import/Export**: GeoJSON/GPX serialization with file system integration
- **Navigation & Actions**: AppBar actions and App Drawer with organized feature access

## Data Sources

- **Gravel Roads**: Overpass API queries for OpenStreetMap data
  - Viewport-based fetching with 500ms debounce
  - Background parsing using `compute` for performance
- **Map Tiles**: OpenStreetMap standard tiles for all themes

## Implementation Benefits

Achieve these advantages through proper architecture:

1. **Separation of Concerns**: Assign each component a single responsibility
2. **Maintainability**: Organize code for easy location, understanding, and modification
3. **Testability**: Enable independent unit testing of services and utilities
4. **Reusability**: Design components for reuse across the application
5. **Scalability**: Add new features without increasing complexity
6. **Collaboration**: Enable multiple developers to work on different components

## Import Dependency Rules

Follow these import relationship requirements:

- Configure `main.dart` to import models, utils, and widgets only
- Keep services self-contained with minimal cross-dependencies
- Allow widgets to depend only on utils for shared functionality
- Maintain models with no internal dependencies except external packages

## Migration Requirements

Apply these migration standards:

- **Original**: Replace monolithic `main_original_backup.dart` (1,816 lines)
- **Refactored**: Organize into `main.dart` (1,459 lines - 20% reduction)
- **Cleanup**: Remove unused refactoring artifacts and resolve all analysis issues
- **Compatibility**: Preserve all functionality and maintain user data
- **Dependencies**: Establish clean import relationships with minimal cross-dependencies

## Development Standards

Implement these development practices:

- **Performance**: Run JSON parsing on background isolates
- **UI**: Apply Material 3 theming with Swedish localization
- **Testing**: Include widget tests for core functionality
- **Build**: Display version/build watermark from pubspec.yaml and CI
- **Web Compatibility**: Implement comprehensive icon loading and PWA optimization

## Migration Notes

- **Original**: monolithic `main_original_backup.dart` (1,816 lines)
- **Refactored**: organized `main.dart` (1,459 lines - 20% reduction)
- **Cleanup**: Removed unused refactoring artifacts and resolved all analysis issues
- **Compatibility**: All functionality preserved, user data maintained
- **Dependencies**: Clean import relationships with minimal cross-dependencies

## Development Notes

- **Performance**: JSON parsing runs on background isolates
- **UI**: Material 3 theming with Swedish localization
- **Testing**: Widget tests included for core functionality
- **Build**: Version/build watermark from pubspec.yaml and CI
- **Web Compatibility**: Comprehensive icon loading and PWA optimization

## Change Log

- **2025‑08‑25**: Web App Enhancement - Updated app branding to "Gravel First", comprehensive web icon compatibility with Material Icons preloading, JavaScript font loading, and cross-platform CSS optimizations
- **2025‑08‑25**: Android Icon Compatibility Fix - Resolved icon visibility issues on Android devices with filled icon variants, explicit IconTheme configuration, and Android build optimizations
- **2025‑08‑25**: Code Quality Cleanup - Resolved all Flutter analysis issues, removed unnecessary imports, added missing curly braces, cleaned up unused refactoring artifacts
- **2025‑08‑25**: Icon Visibility Improvements - Enhanced cross-platform compatibility with Google Material Icons, outlined variants for better contrast, and consistent theming
- **2025‑08‑25**: Major Refactoring - Restructured from monolithic to layered architecture (20% code reduction)
- **2025‑08‑25**: Saved Routes - Local storage for up to 5 named routes with SharedPreferences
- **2025‑08‑24**: Core Features - GPX/GeoJSON import/export, editable points, loop support, GPS integration

---
Last updated: 2025‑08‑25
