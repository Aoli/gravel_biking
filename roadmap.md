# Roadmap

This document tracks feature work one by one with clear status and brief notes.

- [x] **Code Quality Cleanup**: Resolved all Flutter analysis warnings and issues.
  - Status: Done (2025‑08‑25)
  - What: Cleaned up codebase to pass Flutter analysis with zero issues:
    - Removed unnecessary `dart:typed_data` import (elements available in `flutter/foundation.dart`)
    - Added missing curly braces for single-statement if blocks in main.dart and backup
    - Removed unused refactoring leftover files (`lib/main_new.dart`, `lib/screens/map_screen.dart`)
    - Cleaned up empty directories and unused imports
  - Benefits: Cleaner codebase, better maintainability, CI-ready analysis passing

- [x] **Icon Visibility Improvements**: Enhanced cross-platform icon compatibility and visibility.
  - Status: Done (2025‑08‑25)
  - What: Improved icon visibility across Android devices and web apps using Google Material Icons:
    - Added Google Fonts Material Icons CDN to `web/index.html` for better web compatibility
    - Updated all icons to outlined variants for improved contrast (e.g., `my_location_outlined`, `straighten_outlined`)
    - Replaced problematic icons: `folder_open`→`folder`, `file_open`→`upload_file`, `alt_route`→`terrain`
    - Consistent theming for all drawer and UI icons
  - Benefits: Better visibility on all platforms, consistent styling, enhanced web app compatibility

- [x] **Major Code Refactoring**: Restructure monolithic main.dart into organized architecture.
  - Status: Done (2025‑08‑25)
  - What: Refactored 1,816-line main.dart into modular structure with layers:
    - `models/` for data structures
    - `services/` for business logic (route, location, file operations)
    - `utils/` for utility functions
    - `widgets/` for reusable UI components
  - Result: Reduced main.dart to 1,459 lines (20% reduction) while preserving all functionality
  - Benefits: Improved maintainability, testability, code organization, and developer collaboration

- [x] Saved Routes: Save up to 5 named routes locally on device.
  - Status: Done (2025‑08‑25)
  - What: Save current routes with custom names, stored locally using SharedPreferences. Quick-save button in distance panel and full management in drawer.
  - Notes: Routes auto-center when loaded; FIFO removal when limit exceeded; JSON serialization for persistence.

- [x] Subtle build/version watermark overlay.
  - Status: Done (2025‑08‑24)
  - What: Bottom‑left label like "v0.1.0 #27". Version automatically read from pubspec.yaml; build number from CI via `--dart-define=BUILD_NUMBER`.
  - Notes: Also displayed in app drawer footer. Uses package_info_plus for automatic version detection.

- [x] Fix icon contrast in app drawer and locate me button.
  - Status: Done (2025‑08‑25)
  - What: Improved visibility of drawer icons and locate me button in both light and dark themes.
  - Notes: Changed drawer icons to use `onSurface` color; locate me uses `onSecondaryContainer` for proper contrast.

- [x] Prepare TRV NVDB gravel overlay switch (disabled).
  - Status: Done (2025‑08‑25)
  - What: Added second gravel overlay switch in drawer for future Trafikverket NVDB integration.
  - Notes: Switch is disabled (`onChanged: null`) and ready for future API implementation.

- [x] Toggle measurement mode on/off so map taps don't always add points.
  - Status: Done (2025‑08‑24)
  - Notes: Added AppBar toggle (straighten icon) with green (on) / red (off) background. Map onTap only adds points when enabled. Panel stays compact; Undo/Clear retained.

- [x] Close loop support and loop distance reporting.
  - Status: Done (2025‑08‑24)
  - What: You can close/re-open the loop via a button in the distance panel (visible when 3+ points). When closed, the polyline connects last→first and the panel lists a "Loop segment" plus updated total.
  - Notes: Adding a new point automatically re-opens the loop; Undo/Clear recompute segments. Implementation lives in `lib/main.dart` with `_loopClosed` state and `_recomputeSegments()` logic.

- [x] Editable points (tap to select and move; long‑press to delete).
  - Status: Done (2025‑08‑24)
  - What: Tap a marker to select it, then tap on map to move. Long‑press a marker to delete it. Distances recompute and loop state updates.
  - Notes: Selected marker is visually highlighted; panel shows an "Editing point #N" banner with a cancel button.

- [x] Export/import routes (GeoJSON).
  - Status: Done (2025‑08‑24)
  - What: Export current route as GeoJSON (FeatureCollection with a LineString) and import GeoJSON files to restore a route. Preserves loopClosed when present in properties.
  - Notes: Uses `file_picker` and `file_saver` packages. Actions now live in the App Drawer under "GeoJSON".

- [x] Fetch gravel data based on the visible map bounds and refresh on move.
  - Status: Done (2025‑08‑24)
  - What: When the map moves, a 500ms debounce triggers a fetch for the current visible bounds. Parsing happens off the UI thread; polylines are replaced.
  - Notes: Avoids redundant calls by comparing last fetched bounds with a small tolerance.

- [x] GPX import/export support.
  - Status: Done (2025‑08‑24)
  - What: Export current route as GPX 1.1 (trk/trkseg/trkpt). Import GPX and populate route points from trkpt lat/lon. Loop inferred if the track is closed (first==last); dedupes last point internally.
  - Notes: Actions live in the App Drawer under "GPX".

- [x] Improve discoverability of Import/Export by moving actions to an App Drawer with ExpansionTiles.
  - Status: Done (2025‑08‑24)
  - Notes: Drawer contains GeoJSON and GPX sections (initiallyExpanded: false). Replaced the earlier on-map card/buttons. Icons and text use high contrast.

- [x] Add "Locate me" (GPS) button.
  - Status: Done (2025‑08‑24)
  - What: Requests permission via geolocator and shows a circular marker at current position. Error toasts if services disabled or permission denied.

- [x] Center map on my location when using "Locate me".
  - Status: Done (2025‑08‑24)
  - What: After location is acquired, the map recenters to your position using the last known zoom level (fallback to 14).
  - Notes: Uses a `MapController.move(latLng, zoom)` call; currently instant (no animation). We can add a smooth camera animation later if desired.

- [x] Make route point markers smaller and remove numeric labels.
  - Status: Done (2025‑08‑24)
  - Notes: Markers are now compact circular dots with a subtle border/shadow; editing selection is highlighted.

- [x] Add a Drawer switch to toggle the Overpass gravel overlay visibility.
  - Status: Done (2025‑08‑24)
  - Notes: New "Gravel overlay" SwitchListTile in the Drawer controls visibility of the gravel PolylineLayer.

- [x] Standardize map tiles to OpenStreetMap for both light and dark themes.
  - Status: Done (2025‑08‑24)
  - Notes: Removed Stadia dark tiles; now using the same OSM tile URL for all themes.

- [ ] Caching and offline support for both tiles and fetched geometries.
  - Criteria: Tiles cached with sensible max-age; offline viewing of previously seen areas; cached gravel data persistence.
  - Approach: Consider flutter_map_tile_caching for tiles (note GPLv3/commercial licensing considerations), or a simple custom cache. Persist Overpass results locally (e.g., sqflite/hive) keyed by bbox/zoom.

---
Last updated: 2025‑08‑25
