# Gravel First

Plan gravel rides on an interactive map. See ## Using the app

- **AppBar**
  - Locate me: centers a marker at your current GPS position (after permission).

- **Map Interactions**
  - Tap to add points (when measurement mode is enabled via Distance Panel). A polyline connects them.
  - **Visual route indicators**:
    - **Open routes**: Start point (green with play icon), end point (red with stop icon), intermediate points (blue)
    - **Closed loop routes**: Start/end point (orange with refresh icon), intermediate points (blue)
  - **Normal Mode**: Tap empty map areas to add new points.
  - **Edit Mode**: Enhanced point manipulation with safety-first gestures:
    - **Tap a point**: Select the point for position editing (safer than deletion).
    - **Long-press a point**: Show confirmation dialog for deletion (prevents accidents).
    - **Midpoint insertion**: In edit mode, + markers appear between points - tap to add a new point there.
  - **Distance feedback**: Tap any point (in non-edit mode) to see compact distance overlay "P2 2.79km från Start" in lower left corner.

- **Distance Panel** (Enhanced editing controls with hierarchical control system)
  - Shows per-segment distances and the total distance.
  - **Mode Control**: Segment switch with green "Redigera" (enables measurement and editing) / red "View mode" (measurement disabled, editing hidden).
  - **Edit Toggle**: Appears only in "Redigera" mode - enter edit mode for comprehensive point manipulation.
  - **Undo**: Remove the last edit operation with universal undo system.
  - **Save**: Save current route with a custom name (diskette icon for clarity).
  - **Clear**: Remove all points and start over (with confirmation dialog).
  - **Close/Open loop**: Appears when you have 3+ points - connects last point to first.
  - **Distance Markers Toggle**: Show/hide distance markers independently of mode.
  - **Edit Instructions**: When in edit mode, displays comprehensive guidance for all editing operations.

- **Drawer** (hamburger menu)
  - **Saved Routes**: Save up to 50 named routes locally with search and filtering capabilities.
  - **GeoJSON**: Import a LineString from file; Export your current route.
  - **GPX**: Import a track; Export your current route as GPX 1.1.
  - **Distance Markers**: Generate regular distance markers along your route at customizable intervals (0.5km - 10km) with orange square markers showing "1k", "2k", etc. Tap any marker to see distance confirmation overlay.

## Table of Contents

- What this app does
- Core features
- Quick start
- Using the app
- How it works (at a glance)
- Data sources & tiles
- Permissions
- Testing
- Troubleshooting
- Roadmap

## What this app does

Gravel First is a cross‑platform Flutter app that overlays gravel roads on a map and lets you sketch and analyze routes:

- Tap to drop points; a polyline connects them in order.
- See per‑segment distances and a running total.
- Close the loop to connect last→first and include the loop segment in totals.
- Import/export routes as GeoJSON and GPX.
- Use “Locate me” to get your current position, center the map there, and place a marker.

It runs on Android, iOS, Web, macOS, Linux, and Windows.

## Core features

- **Cross-platform icon compatibility**: All icons use Material Design with Google Fonts integration for consistent visibility across Android, iOS, and web platforms

- **Interactive gravel overlay** from OpenStreetMap via the Overpass API, fetched for the current visible map bounds (debounced while panning/zooming).

- **Advanced measurement system** with comprehensive editing capabilities:
  - Measurement mode with a green/red toggle in the AppBar.
  - Add points by tapping the map (when enabled).
  - **Professional point editing**: Enter edit mode for full route manipulation:
    - **Safe deletion**: Tap any point to delete it (preventing accidental deletions).
    - **Position editing**: Long-press a point, then tap anywhere to move it there.
    - **Midpoint insertion**: Add points between existing route points using + markers.
  - Undo last point, Clear all points.
  - Close/Open loop: adds a final loop segment to the list and total.

- **Enhanced Saved Routes**: Save up to 50 named routes locally on your device with advanced management:
  - Routes are automatically centered when loaded.
  - Search functionality by route name and description.
  - Advanced filtering: distance range, route type, date range, proximity.
  - Route name editing with validation.
  - Accessible from the drawer and quick-save button in the distance panel.
  - Automatic FIFO removal when storage limit is reached.
- Import/Export
  - GeoJSON LineString export/import.
  - GPX 1.1 export/import (trk/trkseg/trkpt). If the first and last points are the same, loop is inferred.
- Locate me (GPS): requests permission, recenters the map on your location, and shows a marker where you are.
- App Drawer for actions: Import/Export (GeoJSON, GPX) live under ExpansionTiles.
  - Tiles are closed by default. Two gravel overlay switches: "Gravel overlay" (Overpass/OSM) and "TRV NVDB gravel overlay" (disabled, prepared for Swedish Trafikverket data).
  - Saved routes section with list of all saved routes and management options.
  - Version and build info displayed in footer (auto-detected from pubspec.yaml).

## Quick start

Prerequisites: Flutter SDK installed.

```bash
flutter pub get
flutter run
```

On Web, the app starts in a browser; on mobile/desktop, select a device in your IDE or via `-d`.

## Using the app

- AppBar
  - Measure toggle: green when on, red when off. When on, taps add points; when off, taps don’t add points.
  - Locate me: centers a marker at your current GPS position (after permission).
- Map
  - Tap to add points (when measurement mode is on). A polyline connects them.
  - Tap a point to select it, then tap elsewhere to move it. Long‑press a point to delete it.
- Distance panel
  - Shows per‑segment distances and the total. Buttons for Undo and Clear.
  - Close loop/Open loop appears when you have 3+ points.
- Drawer (hamburger)
  - GeoJSON: Import a LineString from file; Export your current route.
  - GPX: Import a track; Export your current route as GPX 1.1.

## How it works (at a glance)

- **Map rendering**: `flutter_map` provides a Leaflet‑style map with tile layers.

- **Gravel fetch**: When the viewport changes, a 500ms debounce triggers an Overpass API request for gravel roads. JSON is parsed off the UI thread using `compute` and drawn as polylines.

- **Advanced measurement system**: Route points are stored and distances computed with `latlong2.Distance`. Comprehensive editing system includes:
  - **Safety-first gestures**: Tap to delete points, long-press to edit position (prevents accidental deletions).
  - **Professional editing workflow**: Clear edit mode entry/exit with visual feedback and instructions.
  - **Midpoint insertion**: Add points between existing route points using visual + markers.
  - **Context-aware interactions**: Gesture behavior adapts based on edit mode state.
  - Loop mode adds a last→first segment for closed routes.

- **Enhanced Saved Routes**: Up to 50 routes stored locally using `Hive` database with advanced management:
  - Real-time search by name and description.
  - Multi-criteria filtering: distance range, route type, date range, proximity.
  - Route name editing with validation and error handling.
  - Automatic SharedPreferences to Hive migration for existing users.
- **Import/Export**: GeoJSON LineString and GPX 1.1 support. File operations use `file_picker` and `file_saver`.
- **Architecture**: Refactored from monolithic structure into organized layers:
  - `models/` - Data structures (SavedRoute)
  - `services/` - Business logic (route, location, file operations)
  - `utils/` - Utility functions (coordinate parsing, formatting)
  - `widgets/` - Reusable UI components (PointMarker, DistancePanel)

See `architecture.md` for detailed architecture documentation and `lib/main.dart` for the implementation.

## Data sources & tiles

- Overpass API (OpenStreetMap): queries gravel roads for the visible bounds.
- Tiles:
  - OpenStreetMap standard tiles (same for light and dark)

Important: OSM’s public tile servers are not intended for production/high‑traffic use. Review their policies and consider a dedicated tile provider with proper attribution and a user agent.

## Permissions

Location permission is requested at runtime for the “Locate me” feature. Ensure platform manifests are configured (Info.plist on iOS; AndroidManifest on Android). See `lib/context/architecture.md` for details.

## Testing

Run the included widget test:

```bash
flutter test -r expanded
```

Note: Under the widget test binding, network calls return 400 by design; the app handles this gracefully during tests.

## Build/version watermark

The app automatically displays its version from `pubspec.yaml` in both the drawer footer and as a subtle bottom‑left map watermark. When building in CI, you can add a build number by passing:

- `--dart-define=BUILD_NUMBER=<run number>` (from your CI)

This results in displays like `v0.1.0 #27`. Locally, only the version shows: `v0.1.0`.

## Troubleshooting

- **Icons not visible**: The app uses Material Icons with Google Fonts fallback for web compatibility. If icons appear blank, ensure proper network connectivity for web apps or restart the application.
- No gravel lines visible: the Overpass API may be rate‑limited, or the area might not have tagged gravel roads. Try panning/zooming or wait and retry.
- Widget test logs 400 responses: expected in tests; real devices will make network calls.
- Tile usage: if you see rate‑limit or policy warnings, consider switching to a provider with an API key.

## MapTiler key (safe and simple)

Keep your key out of source control and pass it at runtime.

- Copy the example file and set your key locally (gitignored):
  - `env.local.example.json` → `env.local.json`, then put your key in the `MAPTILER_KEY` field.
- Run with the file:

```bash
# Web
flutter run -d chrome --dart-define-from-file=env.local.json

# Android
flutter run -d emulator-5554 --dart-define-from-file=env.local.json

# iOS
flutter run -d ios --dart-define-from-file=env.local.json
```

Builds:

```bash
# Web
flutter build web --dart-define-from-file=env.local.json

# Android
flutter build apk --dart-define-from-file=env.local.json

# iOS
flutter build ios --dart-define-from-file=env.local.json
```

Notes:

- `env.local.json` is in .gitignore. Do not commit your key.
- For web, set domain restrictions in your MapTiler dashboard.

## Roadmap

The active roadmap and change history are tracked in `roadmap.md`.

---
Last updated: 2025‑08‑25
