# Gravel Biking – Architecture & Tech Overview

## Table of Contents

- Overview
- Tech Stack
- System Architecture
- Key Features
- Code Layout
- Data & Tiles
- Measurement Details
- How to Run
- Testing
- Development Notes
- Roadmap
- Change Log

This document provides a concise overview of the Gravel Biking Flutter project: what it does, how it’s organized, the main dependencies, and how to run and test it.

## Overview

A cross‑platform Flutter app that displays a map with gravel roads (queried from OpenStreetMap via Overpass API) and lets you measure custom routes:

- Tap the map to place points (dots).
- Dots are connected with a polyline.
- Per‑segment and total distances are calculated and shown in a corner panel.

## Tech Stack

- Flutter (Dart >= 3.9)
- flutter_map (map rendering; Leaflet-style in Flutter)
- latlong2 (geodesic distance calculations)
- http (fetching gravel road geometry via Overpass API)

Supported platforms (project folders present): Android, iOS, Web, macOS, Linux, Windows.

## System Architecture

Logical components and responsibilities:

- Map UI (flutter_map)
  - Renders tiles, overlays gravel polylines and the measurement polyline/markers.
  - Handles user interactions (map taps, marker taps/long‑press).
- Data Fetcher (Overpass)
  - Issues Overpass queries (http) to retrieve gravel ways.
  - Parses JSON off the UI thread (compute) into Polyline models.
  - Debounced viewport-based fetching on map movement (500ms).
- Measurement Manager
  - Manages route points, editing selection, open/closed loop state.
  - Computes per‑segment distances and totals with latlong2.Distance.
- Import/Export
  - Serializes current route to GeoJSON (LineString) and saves via file_saver.
  - Loads GeoJSON via file_picker and hydrates route state; preserves loop flag when present.

## Key Features

- Gravel roads overlay fetched from Overpass API (OpenStreetMap data) for a fixed bounding box.
  - Viewport-based refresh: updates gravel overlay when you pan/zoom (debounced).
- Tap‑to‑measure routes:
  - Drop markers on tap; a polyline connects them in order.
  - Segment distances (between consecutive points) and total distance.
  - Undo last point and Clear all.
  - Editable points: tap a marker to select, tap map to move; long‑press to delete.
  - Close/Open loop: connect last→first, adds a loop segment to the list and total.
- Import/Export (GeoJSON): export current route as GeoJSON; import a GeoJSON LineString to restore.
- Light/Dark tile styles (OSM standard tiles for light, Stadia “alidade_smooth_dark” tiles for dark).

## Code Layout

Top-level folders of interest:

- `lib/` — application source (entry point: `lib/main.dart`).
- `test/` — Flutter widget tests (`test/widget_test.dart`).
- Platform folders: `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`.

Important files:

- `lib/main.dart`
  - App scaffold and theming.
  - `GravelStreetsMap` stateful widget.
  - Overpass fetch to retrieve gravel street polylines.
  - Measurement logic using `latlong2.Distance`.
  - Map interaction: `MapOptions(onTap: ...)` to add points.
  - UI: `MarkerLayer` for points; `PolylineLayer` for gravel and measured route; overlay distance panel with Undo/Clear.
- `pubspec.yaml`
  - Declares dependencies: `flutter_map`, `latlong2`, `http`, etc.

## Data & Tiles

- Data source: Overpass API (`https://overpass-api.de/api/interpreter`) with a query for ways where `surface=gravel` and `highway` among a selected set within a bounding box (currently hardcoded around Stockholm area).
- Tile servers:
  - Light: OpenStreetMap standard tiles: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
  - Dark: Stadia Maps “alidade_smooth_dark”: `https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png`

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

- Overpass query is simple and uses a fixed bounding box. You can expand it or make it dynamic based on viewport in the future.
- Gravel polyline color is currently a fixed color to avoid theme access during `initState`.
- For tile usage in production, configure a proper provider, keys, and a descriptive `userAgentPackageName`.

## Roadmap

The roadmap lives alongside this document for clarity:

- See: `lib/context/roadmap.md`

---
Last updated: 2025‑08‑24

## Change Log

- 2025‑08‑24: Added GeoJSON import/export (file_picker, file_saver). UI buttons in panel.
- 2025‑08‑24: Editable points (tap‑to‑move, long‑press delete) and editing banner/highlight.
- 2025‑08‑24: Implemented loop close/open with extra loop segment reporting. Updated docs with TOC and notes.
