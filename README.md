# Gravel First

Plan gravel rides on an interactive map. See ## Using the app

- AppBar
  - Measure toggle: green when on, red when off. When on, taps add points; when off, taps don't add points.
  - Locate me: centers a marker at your current GPS position (after permission).
- Map
  - Tap to add points (when measurement mode is on). A polyline connects them.
  - Tap a point to select it, then tap elsewhere to move it. Long‑press a point to delete it.
- Distance panel
  - Shows per‑segment distances and the total. Buttons for Undo, Save, and Clear.
  - Save button (bookmark icon): quickly save current route with a custom name.
  - Close loop/Open loop appears when you have 3+ points.
- Drawer (hamburger)
  - Saved Routes: Save up to 5 named routes locally. Tap any saved route to load it (map auto-centers). Delete routes with trash icon.
  - GeoJSON: Import a LineString from file; Export your current route.
  - GPX: Import a track; Export your current route as GPX 1.1.rom OpenStreetMap, measure custom routes with per‑segment and total distances, import/export your routes (GeoJSON/GPX), and quickly jump to your current GPS position.

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
- Gravel overlay from OpenStreetMap via the Overpass API, fetched for the current visible map bounds (debounced while panning/zooming).
- Measurement mode with a green/red toggle in the AppBar.
  - Add points by tapping the map (when enabled).
  - Undo last point, Clear all.
  - Editable points: tap a point to select then tap on the map to move; long‑press a point to delete.
  - Close/Open loop: adds a final loop segment to the list and total.
- Saved Routes: Save up to 5 named routes locally on your device.
  - Routes are automatically centered when loaded.
  - Accessible from the drawer or quick-save button in the distance panel.
  - Oldest routes are automatically removed when the limit is reached.
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
- **Measurement**: Route points are stored and distances computed with `latlong2.Distance`. Loop mode adds a last→first segment.
- **Saved Routes**: Up to 5 routes stored locally using `SharedPreferences` with JSON serialization. FIFO removal when limit exceeded.
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

## Roadmap

The active roadmap and change history are tracked in `roadmap.md`.

---
Last updated: 2025‑08‑25
