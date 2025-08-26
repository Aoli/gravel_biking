# GitHub Copilot Instructions for Gravel First

This document provides GitHub Copilot with specific context and guidelines for working with the Gravel First ### Code Quality Standards

### Documentation

- Use dartdoc comments for public APIs
- Document complex algorithms and business logic (filtering, geographic calculations)
- Maintain `docs/architecture.md` for major structural changes
- Update `docs/roadmap.md` for feature planning and change tracking
- Always check existing documentation in `/docs` before creating new files

### Data Storage

- Use Hive type adapters for type-safe database operations
- Generate adapters with `build_runner` for model classes
- Implement proper error handling for database operations
- Use FIFO removal patterns for storage limitspplication.

## Project Overview

**Gravel First** is a cross-platform Flutter app for planning gravel bike routes using interactive maps. The app displays gravel roads from OpenStreetMap and provides tools for measuring custom routes with import/export capabilities.

## Documentation Structure

All project documentation is organized in the `/docs` folder:

- `docs/architecture.md` - Complete architecture and technical implementation details
- `docs/roadmap.md` - Feature roadmap and change history
- `.github/copilot-instructions.md` - This file with Copilot-specific guidance

**Important**: Always check existing documentation in `/docs` before creating new files to avoid duplication.

## Platform Development Priorities

### Current Focus: WebApp for All Devices

- **Primary Target**: Web application accessible on all platforms (Android, iOS, desktop)
- **Active Development**: Enhanced web compatibility, icon loading, PWA features
- **Status**: Production-ready with comprehensive cross-platform icon support

### Future Development: Native Mobile Apps

- **Android App**: Planned for future development (currently pending)
- **iOS App**: Planned for future development (currently pending)
- **Preparation**: Code structure supports native development with path_provider for iOS file operations

### Platform-Specific Considerations

- **Web Priority**: Focus on WebApp compatibility across all devices and browsers
- **File Operations**: Implemented with path_provider for future iOS compatibility
- **Icon System**: Enhanced Material Icons loading for Android WebView reliability
- **Cross-Platform**: Maintain code structure that supports future native app development

## Documentation Guidelines

### Language Requirements

- **Write ALL documentation in English** - This is mandatory regardless of the human developer's chat language
- **Maintain English consistency** - Even if the developer communicates in Swedish or other languages, all documentation must be in English
- **Code comments**: Use English for all dartdoc comments and inline documentation

### Documentation Style Standards

- **Use imperative mood** - Write clear directives (e.g., "Use StatefulWidget" not "You should use StatefulWidget")
- **Write actionable statements** - Provide concrete instructions that both AI and human developers can follow
- **Avoid weak language** - Use decisive language (e.g., "Implement error handling" not "Consider implementing error handling")
- **Structure for clarity** - Use consistent formatting, bullet points, and code examples

### Content Organization

- **Place all documentation in `/docs` folder** - Never create documentation files in other locations
- **Use descriptive filenames** - Choose names that clearly indicate content purpose
- **Maintain cross-references** - Link related documentation sections appropriately
- **Update systematically** - Keep documentation current with code changes

### Architecture Documentation Format

- **Write in imperative style** - Provide clear directives for implementation
- **Focus on "how to implement"** - Give practical guidance for developers
- **Include code examples** - Show concrete implementation patterns
- **Specify requirements** - State what must be done, not suggestions

## Architecture Guidelines

### Code Organization

- Follow the established layered architecture: `models/`, `services/`, `utils/`, `widgets/`
- Keep `main.dart` focused on app entry point and primary map functionality
- Place reusable components in `widgets/` with proper theming support
- Use `services/` for business logic and external API integrations

### Design Patterns

- **Material 3**: Use Material Design 3 components and theming
- **State Management**: StatefulWidget with setState for local state
- **Async Operations**: Use `compute` for heavy processing (JSON parsing)
- **Error Handling**: Provide user-friendly error messages with fallbacks

## Technical Standards

### Flutter/Dart

- **Dart Version**: >= 3.9
- **Null Safety**: Enabled throughout the codebase
- **Linting**: Follow Flutter lints with zero analysis issues
- **Formatting**: Use standard Dart formatting (`dart format`)

### Dependencies

```yaml
# Core Dependencies
flutter_map: ^7.0.2 # Map rendering (Leaflet-style)
latlong2: ^0.9.1 # Geodesic calculations
http: ^1.2.2 # API requests
geolocator: ^12.0.0 # GPS positioning
file_picker: ^8.3.7 # File selection
file_saver: ^0.2.14 # File saving
xml: ^6.5.0 # GPX parsing
package_info_plus: ^8.3.1 # App version info
path_provider: ^2.1.4 # iOS-compatible file path access

# Enhanced Storage
hive: ^2.2.3 # High-performance database
hive_flutter: ^1.1.0 # Flutter Hive integration

# Development Dependencies
hive_generator: ^2.0.1 # Code generation for adapters
build_runner: ^2.4.7 # Build system for code generation
```

### Icons and UI

- **Icon System**: Use Google Material Icons (filled variants preferred)
- **Cross-platform**: Ensure Android, iOS, and web compatibility
- **Theming**: Support both light and dark themes
- **Accessibility**: Follow Material accessibility guidelines

## Feature Implementation Guidelines

### Map Integration

- Use `flutter_map` with OpenStreetMap tiles
- Implement viewport-based data fetching with debouncing (500ms)
- Parse JSON data off the main thread using `compute`
- Use `MapController` for programmatic map operations

### Route Management

- Store routes using `Hive` with type adapters for type-safe storage
- Support up to 50 saved routes with automatic FIFO removal
- Advanced filtering: distance range, route type, date range, proximity-based
- Route editing: name editing with validation and update capabilities
- Use `LatLng` from `latlong2` for coordinate representation
- Calculate distances with geodesic algorithms (Haversine formula)
- Search functionality for route names and metadata

### File Operations

- Support GeoJSON (LineString) and GPX 1.1 formats
- Preserve loop state and metadata in exports
- Use system file picker/saver for cross-platform compatibility
- Implement path_provider for iOS file system access
- Use conditional platform handling (kIsWeb vs mobile)
- Validate file formats before processing

### Location Services

- Request permissions gracefully with error handling
- Provide fallback behavior for denied/unavailable GPS
- Center map on user location with appropriate zoom levels

## Code Quality Standards

### Documentation

- Use dartdoc comments for public APIs
- Document complex algorithms and business logic
- Maintain `docs/architecture.md` for major structural changes
- Update `docs/roadmap.md` for feature planning and change tracking
- Always check existing documentation in `/docs` before creating new files
- Maintain a consistent documentation style and structure
- Include code examples where applicable
- Use clear and descriptive titles for all documentation sections
- When creating new md-files, put them in `docs/` directory

### Testing

- Write widget tests for UI components
- Test business logic in services independently
- Ensure cross-platform compatibility

### Performance

- Use `compute` for JSON parsing and heavy calculations
- Debounce API requests to prevent excessive calls
- Optimize widget rebuilds with proper state management

## API Integration

### Overpass API

```dart
// Query pattern for gravel roads
final query = '''
[out:json][timeout:25];
(
  way[highway~"^(track|path|cycleway|footway|bridleway|unclassified|tertiary|secondary|primary|trunk|residential|service)$"]
     [surface~"^(gravel|compacted|fine_gravel|pebblestone|ground|earth|dirt|grass|sand|unpaved|cobblestone)$"]
     (${bbox.south},${bbox.west},${bbox.north},${bbox.east});
);
out geom;
''';
```

### File Format Support

- **GeoJSON**: LineString with optional loop property
- **GPX**: Track format with `<trk><trkseg><trkpt>` structure
- Preserve route metadata and timestamps

## Branding and Localization

- **App Name**: "Gravel First"
- **Primary Language**: Swedish localization where appropriate
- **Web App**: PWA-ready with proper manifest and meta tags
- **Icon Branding**: Use consistent iconography throughout

## Web Optimization

### PWA Configuration

- Proper `manifest.json` with app branding
- Material Icons CDN integration with fallbacks
- Service worker for offline capability
- Responsive design for mobile and desktop

### Font Loading

- Preload Material Icons fonts
- Provide fallback fonts for reliability
- Use `font-display: swap` for better loading experience

## Common Patterns

### Error Handling

```dart
try {
  // API operation
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User-friendly error message')),
    );
  }
}
```

### Async Operations

```dart
final result = await compute(parseJsonData, jsonString);
```

### Theme-aware Components

```dart
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
```

## Platform-Specific Notes

### Android

- Handle location permissions in manifest
- Use filled icon variants for better visibility
- Test on various screen densities

### iOS

- Configure `Info.plist` for location usage
- Test on different device sizes
- Ensure proper safe area handling

### Web

- Material Icons CDN integration with multiple format support
- Proper meta tags for SEO and PWA functionality
- Service worker configuration for offline capability
- Enhanced Android WebView compatibility with font loading
- File operations with web-safe APIs and fallback handling

## Development Workflow

1. **Feature Development**: Create branch from `develop`
2. **Code Quality**: Run `flutter analyze` and `dart format`
3. **Testing**: Ensure widget tests pass
4. **Build Verification**: Test on target platforms
5. **Documentation**: Update relevant documentation files

## Best Practices

- Follow the single responsibility principle
- Use meaningful variable and function names
- Implement proper error boundaries
- Optimize for both performance and maintainability
- Consider accessibility in UI design
- Write self-documenting code with clear intentions

---

This document should be updated when significant architectural changes are made to maintain accuracy for GitHub Copilot assistance.
