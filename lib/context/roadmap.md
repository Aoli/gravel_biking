# Roadmap

This document tracks feature work one by one with clear status and brief notes.

- [x] Toggle measurement mode on/off so map taps don’t always add points.
  - Status: Done (2025‑08‑24)
  - Notes: Added AppBar toggle (straighten icon) with green (on) / red (off) background. Map onTap only adds points when enabled. Panel stays compact; Undo/Clear retained.

- [x] Close loop support and loop distance reporting.
  - Status: Done (2025‑08‑24)
  - What: You can close/re-open the loop via a button in the distance panel (visible when 3+ points). When closed, the polyline connects last→first and the panel lists a “Loop segment” plus updated total.
  - Notes: Adding a new point automatically re-opens the loop; Undo/Clear recompute segments. Implementation lives in `lib/main.dart` with `_loopClosed` state and `_recomputeSegments()` logic.

- [x] Editable points (tap to select and move; long‑press to delete).
  - Status: Done (2025‑08‑24)
  - What: Tap a marker to select it, then tap on map to move. Long‑press a marker to delete it. Distances recompute and loop state updates.
  - Notes: Selected marker is visually highlighted; panel shows an “Editing point #N” banner with a cancel button.

- [x] Export/import routes (GeoJSON).
  - Status: Done (2025‑08‑24)
  - What: Export current route as GeoJSON (FeatureCollection with a LineString) and import GeoJSON files to restore a route. Preserves loopClosed when present in properties.
  - Notes: Uses `file_picker` and `file_saver` packages. Actions now live in the App Drawer under “GeoJSON”.
  - Follow-up: Add GPX support if needed. (Completed below.)

- [x] Fetch gravel data based on the visible map bounds and refresh on move.
  - Status: Done (2025‑08‑24)
  - What: When the map moves, a 500ms debounce triggers a fetch for the current visible bounds. Parsing happens off the UI thread; polylines are replaced.
  - Notes: Avoids redundant calls by comparing last fetched bounds with a small tolerance.

- [x] GPX import/export support.
  - Status: Done (2025‑08‑24)
  - What: Export current route as GPX 1.1 (trk/trkseg/trkpt). Import GPX and populate route points from trkpt lat/lon. Loop inferred if the track is closed (first==last); dedupes last point internally.
  - Notes: Actions live in the App Drawer under “GPX”.

- [x] Improve discoverability of Import/Export by moving actions to an App Drawer with ExpansionTiles.
  - Status: Done (2025‑08‑24)
  - Notes: Drawer contains GeoJSON and GPX sections (initiallyExpanded: false). Replaced the earlier on-map card/buttons. Icons and text use high contrast.

- [x] Add “Locate me” (GPS) button.
  - Status: Done (2025‑08‑24)
  - What: Requests permission via geolocator and shows a circular marker at current position. Error toasts if services disabled or permission denied.

- [x] Center map on my location when using “Locate me”.
  - Status: Done (2025‑08‑24)
  - What: After location is acquired, the map recenters to your position using the last known zoom level (fallback to 14).
  - Notes: Uses a `MapController.move(latLng, zoom)` call; currently instant (no animation). We can add a smooth camera animation later if desired.

- [x] Make route point markers smaller and remove numeric labels.
  - Status: Done (2025‑08‑24)
  - Notes: Markers are now compact circular dots with a subtle border/shadow; editing selection is highlighted.

- [x] Add a Drawer switch to toggle the Overpass gravel overlay visibility.
  - Status: Done (2025‑08‑24)
  - Notes: New “Gravel overlay” SwitchListTile in the Drawer controls visibility of the gravel PolylineLayer.

- [x] Standardize map tiles to OpenStreetMap for both light and dark themes.
  - Status: Done (2025‑08‑24)
  - Notes: Removed Stadia dark tiles; now using the same OSM tile URL for all themes.

- [x] Subtle build/version watermark overlay.
  - Status: Done (2025‑08‑24)
  - What: Bottom‑left label like “v1.2.3 #27”. Values come from CI via `--dart-define=APP_VERSION` and `--dart-define=BUILD_NUMBER`.
  - Notes: Hidden locally unless dart‑defines are provided.

- [ ] Caching and offline support for both tiles and fetched geometries.
  - Criteria: Tiles cached with sensible max-age; offline viewing of previously seen areas; cached gravel data persistence.
  - Approach: Consider flutter_map_tile_caching for tiles (note GPLv3/commercial licensing considerations), or a simple custom cache. Persist Overpass results locally (e.g., sqflite/hive) keyed by bbox/zoom.

---
Last updated: 2025‑08‑24 (later)
