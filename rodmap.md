# Roadmap

This document tracks feature work one by one with clear status and brief notes.

- [x] Toggle measurement mode on/off so map taps don’t always add points.
  - Status: Done (2025‑08‑24)
  - Notes: Added AppBar toggle (straighten icon). Map onTap only adds points when enabled. Panel stays compact; Undo/Clear retained.

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
  - Notes: Buttons added in the distance panel. Uses `file_picker` and `file_saver` packages.
  - Follow-up: Add GPX support if needed.

- [ ] Fetch gravel data based on the visible map bounds and refresh on move.
  - Criteria: When the camera stops moving, fetch gravel ways for current bounds; throttle/debounce requests; avoid flicker.
  - Approach: Listen to map move end; compute bbox; Overpass fetch on background isolate; merge/replace polylines.

- [ ] Caching and offline support for both tiles and fetched geometries.
  - Criteria: Tiles cached with sensible max-age; offline viewing of previously seen areas; cached gravel data persistence.
  - Approach: Consider flutter_map_tile_caching for tiles (note GPLv3/commercial licensing considerations), or a simple custom cache. Persist Overpass results locally (e.g., sqflite/hive) keyed by bbox/zoom.

---
Last updated: 2025‑08‑24
