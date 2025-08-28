# Gravel First – Architecture & Implementation Guide

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Technical Foundation](#2-technical-foundation)
3. [Architecture Standards](#3-architecture-standards)
4. [Implementation Requirements](#4-implementation-requirements)
5. [System Architecture](#5-system-architecture)
6. [Development Standards](#6-development-standards)
7. [Platform Specifications](#7-platform-specifications)
8. [Spoke Documentation](#8-spoke-documentation)

---

## 1. Project Overview

### 1.1 Application Purpose
Build a cross-platform Flutter application for planning gravel bike routes using interactive maps. Display gravel roads from OpenStreetMap and provide comprehensive tools for measuring custom routes with advanced import/export capabilities.

### 1.2 Architecture Status
**Current State**: Successfully refactored from monolithic to modular architecture:
- **Before**: Single `main.dart` with 1816 lines containing all functionality
- **After**: Modular architecture with 95% size reduction in `main.dart` (88 lines)
- **Benefits**: Improved maintainability, clear separation of concerns, enhanced testability

### 1.3 Key Achievements
- ✅ **General Undo System**: Universal undo functionality with 50-state history management
- ✅ **Comprehensive Testing**: Professional testing framework with 97+ passing tests
- ✅ **Enhanced Route Management**: Hive database supporting 50 routes with advanced filtering
- ✅ **Cross-Platform Compatibility**: iOS, Android, and web deployment ready
- ✅ **Distance Markers System**: Configurable markers with smart positioning
- ✅ **Professional Editing**: Safety-first editing with comprehensive point manipulation

---

## 2. Technical Foundation

### 2.1 Required Technology Stack
Use these specific technologies and versions:

```yaml
# Core Framework
flutter: >= 3.9.0
dart: >= 3.9.0

# Essential Dependencies
flutter_map: ^7.0.2          # Map rendering (Leaflet-style)
latlong2: ^0.9.1             # Geodesic calculations
http: ^1.2.2                 # API requests
geolocator: ^12.0.0          # GPS positioning
file_picker: ^8.3.7          # File selection
file_saver: ^0.2.14          # File saving
xml: ^6.5.0                  # GPX parsing
package_info_plus: ^8.3.1    # App version info
path_provider: ^2.1.4        # iOS-compatible file access

# Enhanced Storage
hive: ^2.2.3                 # High-performance database
hive_flutter: ^1.1.0         # Flutter Hive integration

# Development Dependencies
hive_generator: ^2.0.1       # Code generation for adapters
build_runner: ^2.4.7         # Build system
```

### 2.2 Platform Development Priorities

#### 2.2.1 Current Focus: WebApp for All Devices
- **Primary Target**: Web application accessible on all platforms
- **Active Development**: Enhanced web compatibility, icon loading, PWA features
- **Status**: Production-ready with comprehensive cross-platform icon support

#### 2.2.2 Future Development: Native Mobile Apps
- **Android/iOS Apps**: Planned for future development (currently pending)
- **Preparation**: Code structure supports native development

### 2.3 Icon System Implementation
Implement cross-platform icon compatibility:
- Use Google Material Icons with comprehensive CDN integration
- Apply filled icon variants for universal platform support
- Configure multiple font format preloading (WOFF2, WOFF)
- Implement enhanced Android WebView compatibility with fallback handling

---

## 3. Architecture Standards

### 3.1 Mandatory File Structure

Organize the application using this exact layered structure:

```text
lib/
├── main.dart                    # Clean app entry point (88 lines)
├── screens/
│   ├── gravel_streets_map.dart  # Main map screen (3071 lines)
│   └── saved_routes_page.dart   # Enhanced route management (843 lines)
├── services/
│   ├── measurement_service.dart # Route measurement logic (348 lines)
│   ├── route_service.dart       # Hive-based route management (384 lines)
│   ├── location_service.dart    # GPS location handling (72 lines)
│   └── file_service.dart        # Cross-platform import/export (372 lines)
├── models/
│   ├── saved_route.dart         # Hive data model (101 lines)
│   └── saved_route.g.dart       # Generated Hive adapters (auto-generated)
├── utils/
│   └── coordinate_utils.dart    # Coordinate parsing utilities (29 lines)
├── widgets/
│   ├── point_marker.dart        # Route point marker component (172 lines)
│   └── distance_panel.dart      # Distance measurement panel (644 lines)
└── providers/                   # State management (see state-management.md)
    ├── ui_providers.dart        # UI state providers + RouteState management (220 lines)
    ├── loading_providers.dart   # Loading state management (20 lines)
    └── service_providers.dart   # Service instance providers (42 lines)
```

### 3.2 Import Dependency Rules

Follow these import relationship requirements:

- Configure `main.dart` to import screens, models, and providers only
- Keep services self-contained with minimal cross-dependencies
- Allow widgets to depend on utils and providers for shared functionality
- Maintain models with no internal dependencies except external packages
- Establish clean import relationships preventing circular dependencies

### 3.3 Code Quality Standards

Implement these mandatory standards:

- **Flutter Analysis**: Zero issues tolerance - run `flutter analyze`
- **Null Safety**: Enabled throughout codebase with proper null handling
- **Formatting**: Use standard Dart formatting (`dart format`)
- **Documentation**: dartdoc comments for all public APIs
- **Testing**: Minimum 90% test coverage for business logic

---

## 4. Implementation Requirements

### 4.1 Core Application Layer

#### 4.1.1 Main Application (`main.dart`)

Implement as minimal entry point:

- Configure app scaffold, theming, and Material Design components
- Keep minimal (88 lines) with essential app initialization only
- Import and instantiate `GravelStreetsMap` screen as home widget
- Use clean separation of concerns for maintainability

#### 4.1.2 App Configuration

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravel First',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const GravelStreetsMap(),
    );
  }
}
```

### 4.2 Screen Layer Implementation

#### 4.2.1 GravelStreetsMap Screen

Create the primary map interface with these mandatory responsibilities:

- Contain complete map functionality (2265 lines)
- Integrate Overpass API for gravel road data fetching with 500ms debounce
- Handle all map interactions and comprehensive state management
- Structure UI layout including AppBar actions and drawer navigation
- Render map layers: PolylineLayer for roads/routes, MarkerLayer for points
- Implement advanced editing features with safety-first gesture handling
- Manage application state using Riverpod providers (see state-management.md)

#### 4.2.2 SavedRoutesPage Screen

Build comprehensive route management interface:

- Support up to 50 routes with search and advanced filtering
- Provide real-time text search by name and description
- Include advanced filters: distance range, route type, date range, proximity
- Enable route name editing with validation and error handling
- Implement Material 3 design with Swedish localization
- Support pull-to-refresh and proper state management

### 4.3 Service Layer Architecture

#### 4.3.1 MeasurementService

Implement route measurement and calculation logic (331 lines):

- Handle route point management and distance calculations
- Provide geodesic distance calculations and formatting
- Manage measurement state and coordinate transformations
- Support comprehensive undo system with state history
- Separate business logic from UI components

#### 4.3.2 RouteService

Build enhanced Hive-based route management:

- Support up to 50 routes with automatic storage management
- Implement search functionality for name and description filtering
- Calculate distances and provide route metadata
- Handle automatic SharedPreferences to Hive migration
- Provide CRUD operations: save, load, update, delete routes
- Support advanced filtering by distance, type, date, proximity

#### 4.3.3 FileService

Build cross-platform import/export operations:

- Support GeoJSON LineString and GPX 1.1 formats with metadata preservation
- Use path_provider for iOS-compatible file system access
- Implement conditional platform handling (kIsWeb vs mobile)
- Integrate file picker and saver with proper error handling

#### 4.3.4 LocationService

Create GPS positioning capabilities:

- Handle GPS positioning with proper permission handling
- Enable "Locate me" functionality with map centering
- Provide error handling for disabled services or denied permissions

### 4.4 Models Layer Standards

#### 4.4.1 SavedRoute Model

Create Hive data class with enhanced metadata:

```dart
@HiveType(typeId: 0)
class SavedRoute extends HiveObject {
  @HiveField(0)
  String name;
  
  @HiveField(1)
  List<LatLngData> points;
  
  @HiveField(2)
  bool loopClosed;
  
  @HiveField(3)
  DateTime savedAt;
  
  @HiveField(4)
  String? description;
  
  @HiveField(5)
  double distance;
}
```

#### 4.4.2 LatLngData Model

Implement Hive-compatible coordinate storage:

```dart
@HiveType(typeId: 1)
class LatLngData extends HiveObject {
  @HiveField(0)
  double latitude;
  
  @HiveField(1)
  double longitude;
}
```

### 4.5 Widgets Layer Requirements

#### 4.5.1 PointMarker Widget

Implement route point visualization:

- Configure marker appearance for normal and editing states
- Implement adaptive sizing based on route density (10-20px range)
- Use theme colors with proper border and shadow effects
- Support start/end point indicators with appropriate icons

#### 4.5.2 DistancePanel Widget

Create measurement interface with comprehensive controls:

- Display segment and total distance calculations
- Provide action buttons: Undo, Edit, Save, Clear, Loop toggle
- Show edit instructions and mode indicators during editing
- Include cancel functionality for exiting edit mode

---

## 5. System Architecture

### 5.1 Logical Component Structure

Design system with these architectural layers:

#### 5.1.1 Presentation Layer

- **Map UI**: flutter_map renders tiles, overlays gravel polylines and measurement routes
- **Control Interfaces**: Distance panel, drawer navigation, route management pages
- **State Management**: Riverpod providers for reactive UI updates (see state-management.md)

#### 5.1.2 Business Logic Layer

- **Measurement Manager**: Route points, editing selection, distance calculations with geodesic accuracy
- **Undo System**: State history management with immutable snapshots and universal operation reversal
- **Route Manager**: Hive database with 50-route capacity, search, filtering, and editing capabilities

#### 5.1.3 Data Layer

- **Local Storage**: Hive database for route persistence with automatic migration
- **File Operations**: Cross-platform GeoJSON/GPX import/export with iOS compatibility
- **External APIs**: Overpass API for gravel road data with viewport-based fetching (see api.md)

#### 5.1.4 Platform Integration

- **Location Services**: GPS positioning with proper permission handling
- **File System**: path_provider for cross-platform file access
- **Web Compatibility**: PWA features with offline capability

### 5.2 Data Flow Architecture

Implement unidirectional data flow:

1. **User Input** → UI components capture interactions
2. **State Management** → Riverpod providers process state changes
3. **Business Logic** → Services handle calculations and operations
4. **Data Persistence** → Hive database stores route data
5. **UI Updates** → Reactive UI rebuilds based on state changes

### 5.3 Error Handling Strategy

Build comprehensive error handling:

- **Service Layer**: Catch and handle all external API errors
- **UI Layer**: Display user-friendly error messages with fallbacks
- **Data Layer**: Validate data integrity and provide recovery mechanisms
- **Platform Layer**: Handle platform-specific limitations gracefully

---

## 6. Development Standards

### 6.1 Feature Implementation Standards

#### 6.1.1 Measurement System

Build measurement interface with these features:

- Implement tap-to-measure with toggle mode (green/red indicator)
- Calculate per-segment and total distances using geodesic algorithms
- Enable comprehensive point editing system with safety-first gestures
- Support loop closure with additional segment calculation
- Provide professional editing workflow with clear entry/exit modes

#### 6.1.2 Undo System Implementation

Implement comprehensive undo functionality:

- **Universal Operation Support**: Handle undo for all edit types
- **State History Management**: Maintain up to 50 route state snapshots
- **Complete State Restoration**: Restore all route data including points, loop status, markers
- **Automatic State Saving**: Call `_saveStateForUndo()` before destructive operations
- **Memory Management**: FIFO history queue with configurable limits
- **UI Integration**: Update panels with `canUndo` parameter for conditional button enabling

#### 6.1.3 Distance Markers System

Create configurable distance marker system:

- **Configurable Intervals**: Slider from 0.5km to 10km with 8 preset intervals
- **Smart Generation**: Interpolate exact marker positions along route segments
- **Visual Markers**: Orange square markers with white borders showing distance
- **Interactive Markers**: Tap any marker to show confirmation overlay
- **Toggle Visibility**: Show/hide markers independently of generation
- **Route Integration**: Automatically clear when route is modified

### 6.2 Performance Standards

Achieve these performance requirements:

- **API Requests**: Implement 500ms debounce for viewport-based fetching
- **Background Processing**: Use `compute` for JSON parsing and heavy calculations
- **Memory Management**: Optimize widget rebuilds with proper state management
- **File Operations**: Implement distance-based decimation for large GPX files (>2000 points)

### 6.3 User Experience Standards

Provide professional-grade user experience:

- **Material 3 Design**: Use Material Design 3 components and theming
- **Swedish Localization**: Implement Swedish language support where appropriate
- **Loading States**: Provide loading indicators for all async operations
- **Error Feedback**: Display clear error messages with recovery options
- **Accessibility**: Follow Material accessibility guidelines

---

## 7. Platform Specifications

### 7.1 Web Platform Implementation

Configure web-specific features:

- **PWA Configuration**: Proper manifest.json with app branding
- **Icon Loading**: Material Icons CDN integration with fallbacks
- **Service Worker**: Offline capability implementation
- **Responsive Design**: Mobile and desktop compatibility

### 7.2 Mobile Platform Preparation

Prepare for future native development:

- **Android**: Handle location permissions in manifest, test on various screen densities
- **iOS**: Configure Info.plist for location usage, ensure proper safe area handling
- **File Operations**: Use path_provider for proper iOS file system integration

### 7.3 Cross-Platform Compatibility

Ensure consistent behavior across platforms:

- **Conditional Logic**: Use `kIsWeb` vs mobile platform detection
- **File Handling**: Implement platform-appropriate file operations
- **Font Loading**: Provide fallback fonts for reliability across platforms

---

## 8. Spoke Documentation

This architecture document serves as the central hub for technical implementation. Detailed information for specific domains is available in dedicated spoke documents:

### 8.1 State Management (`state-management.md`)

**Comprehensive Riverpod Implementation Guide**

- Complete provider architecture patterns
- State management best practices
- Migration from StatefulWidget to Riverpod
- Provider types and usage scenarios
- Testing strategies for state management

### 8.2 Testing (`testing.md`)

**Professional Testing Framework Documentation**

- Test-driven development approach
- Unit, widget, integration, and performance testing
- CI/CD pipeline with quality gates
- Testing tools and frameworks
- Coverage requirements and reporting

### 8.3 API Integration (`api.md`)

**External API Documentation and Compliance**

- Overpass API integration patterns
- MapTiler service configuration
- Tile server compliance and usage policies
- API security and validation
- Error handling and fallback strategies

### 8.4 Future Spoke Documents

Additional spoke documents will be created as needed:

- **Deployment Guide**: Production deployment, CI/CD, platform-specific builds
- **Performance Optimization**: Advanced performance tuning and monitoring
- **Internationalization**: Multi-language support and localization strategies

---

## Migration Benefits

### 9.1 Achieved Improvements

Through proper architecture implementation:

1. **Separation of Concerns**: Each component has a single responsibility
2. **Maintainability**: Code organized for easy location and modification
3. **Testability**: Independent unit testing of services and utilities
4. **Reusability**: Components designed for reuse across application
5. **Scalability**: New features added without increasing complexity
6. **Collaboration**: Multiple developers can work on different components

## 10. Documentation Standards

### 10.1 Dart Code Documentation

All Dart files must follow these documentation requirements:

#### **File-Level Documentation**
```dart
/// Brief description of the file's primary purpose
/// 
/// Detailed explanation of key functionality, architectural decisions,
/// and integration patterns. Include usage examples for complex APIs.
```

#### **Class Documentation**
```dart
/// Class purpose and responsibility
/// 
/// **Key Features:**
/// - Feature 1 with brief explanation
/// - Feature 2 with brief explanation
/// 
/// **Usage Pattern:**
/// - How to instantiate and use the class
/// - Important method call sequences
/// - State management considerations
class ExampleClass {
```

#### **Method Documentation**
```dart
/// Method purpose and behavior
/// 
/// **Parameters:**
/// - param1: Description of parameter and valid values
/// - param2: Description with constraints or special handling
/// 
/// **Returns:** Description of return value and possible states
/// 
/// **Side Effects:** Any state changes or external operations
/// 
/// **Performance:** Complexity notes for expensive operations
void exampleMethod(Type param1, Type param2) {
```

### 10.2 Documentation Completeness Status

#### **✅ Fully Documented Files**

- `lib/main.dart` - Complete app entry point documentation
- `lib/models/saved_route.dart` - Full model documentation
- `lib/providers/` - All provider files fully documented
- `lib/utils/coordinate_utils.dart` - Complete utility documentation
- `lib/widgets/point_marker.dart` - Comprehensive widget documentation

#### **🔧 Partially Documented Files**

- `lib/services/measurement_service.dart` - Core methods documented, some getters/setters need docs
- `lib/services/route_service.dart` - Class documented, some complex methods need enhancement
- `lib/services/location_service.dart` - Basic documentation present
- `lib/services/file_service.dart` - Class documented, method docs could be enhanced
- `lib/widgets/distance_panel.dart` - Widget documented, internal methods need docs

#### **📋 Major Documentation Needs**

- `lib/screens/gravel_streets_map.dart` - 3071 lines, minimal documentation
  - Background isolate functions need comprehensive docs
  - Complex state management logic needs explanation
  - Map interaction handlers need documentation

### 10.3 Documentation Maintenance

1. **Update Triggers**: Documentation must be updated when:
   - Adding new public APIs or methods
   - Changing method signatures or behavior
   - Modifying class responsibilities
   - Adding complex algorithms or business logic

2. **Review Process**: All PRs must include documentation updates for:
   - New features or components
   - API changes or enhancements
   - Performance optimizations
   - Bug fixes that change behavior

3. **Documentation Testing**: Use `flutter doc` to verify all public APIs have documentation.

### 9.2 Change History

- **2025-01-27**: Comprehensive Point Editing System - Complete editing overhaul with safety-first gestures
- **2025-08-26**: General Undo System - Universal undo with 50-state history management
- **2025-08-26**: Comprehensive Testing Implementation - Professional testing framework established
- **2025-08-26**: Main.dart Architecture Refactoring - 95% size reduction with modular architecture
- **2025-08-25**: Enhanced Route Management - Hive database with 50-route capacity
- **2025-08-25**: Cross-Platform File Operations - iOS compatibility with path_provider
- **2025-08-25**: Code Quality Cleanup - Zero Flutter analysis issues achieved

---

Last updated: 2025-08-28

This document serves as the central technical hub. Refer to spoke documents for domain-specific implementation details.
