# FixMate — Front-end (Flutter & React Dashboard)

## Overview
- FixMate is a citizen maintenance reporter used to quickly capture and track community issues during a hackathon-style demo.
- This repository contains front-end only implementations: a Flutter mobile/web app and a static React dashboard.
- There is no backend. AI is simulated deterministically. Data is stored locally or loaded from demo JSON.

## Features implemented
- Flutter app tabs: Report, Map, My Reports, Settings (bilingual EN/BM)
- Capture flow: camera/gallery, GPS, deterministic mock AI, local storage
- Map: OSM via flutter_map with clustering, filters, marker details, legend, external maps link
- My Reports: list/detail with status cycle and delete
- Settings: language toggle and clear data
- React dashboard: filters, clustered map, queue, drawer, stats, heatmap toggle

## Tech stack
- Flutter packages: flutter_map, flutter_map_marker_cluster, latlong2, geolocator, image_picker, path_provider, shared_preferences, uuid, url_launcher, provider
- Dashboard: React 18 UMD, Leaflet + markercluster (+ optional heat), Day.js

## Project structure
- Key Flutter files:
  - [lib/app.dart](lib/app.dart:1)
  - [lib/screens/report_flow/capture_screen.dart](lib/screens/report_flow/capture_screen.dart:1)
  - [lib/screens/map/map_screen.dart](lib/screens/map/map_screen.dart:1)
  - [lib/screens/my_reports/my_reports_screen.dart](lib/screens/my_reports/my_reports_screen.dart:1)
  - [lib/screens/settings/settings_screen.dart](lib/screens/settings/settings_screen.dart:1)
  - [lib/services/storage.dart](lib/services/storage.dart:1), [lib/services/mock_ai.dart](lib/services/mock_ai.dart:1), [lib/services/location_service.dart](lib/services/location_service.dart:1)
  - [lib/models/report.dart](lib/models/report.dart:1), [lib/models/enums.dart](lib/models/enums.dart:1)
  - [assets/lang/en.json](assets/lang/en.json:1), [assets/lang/ms.json](assets/lang/ms.json:1)
- Dashboard files:
  - [dashboard/index.html](dashboard/index.html:1), [dashboard/app.js](dashboard/app.js:1), [dashboard/styles.css](dashboard/styles.css:1)
  - [dashboard/i18n/en.json](dashboard/i18n/en.json:1), [dashboard/i18n/ms.json](dashboard/i18n/ms.json:1)
  - [dashboard/data/demo-reports.json](dashboard/data/demo-reports.json:1)

## Running the Flutter app
- Prerequisites: Flutter stable installed and a device/emulator or Chrome for web.
- Commands:
  - flutter pub get
  - flutter run  (or flutter run -d chrome)
- Notes:
  - Android/iOS will prompt for camera and location permissions.
  - On the web, geolocation and camera require HTTPS; some browsers restrict camera on http.
  - Photos are stored as base64 on web; on mobile, images are saved to app storage and paths are persisted (see [lib/services/storage.dart](lib/services/storage.dart:1)).

## Running the React dashboard
- Serve the dashboard folder over HTTP (e.g., VSCode Live Server or Python):
  - cd dashboard &#38;&#38; python -m http.server 8000
- Open http://127.0.0.1:8000 in a browser (or your Live Server URL).
- Behavior:
  - Language toggle persists using localStorage.
  - Filters drive the clustered Leaflet map, queue, drawer, stats, and optional heatmap overlay.

## Known limitations
- No backend; all data is local or demo JSON.
- AI is simulated; severity/category are heuristic and not model-driven.
- Dashboard UI state is not persisted; a refresh resets filters and selections.
- OpenStreetMap tile usage is subject to their terms and rate limits.

## Visual tokens
- Severity colors: High #D32F2F, Medium #F57C00, Low #388E3C
- Status colors: Submitted #1976D2, In Progress #7B1FA2, Fixed #455A64

## License
- Placeholder: add a LICENSE file or specify licensing before distribution.

## Acknowledgements
- OpenStreetMap, Leaflet, flutter_map and community plugins, React, Day.js, Flutter community.