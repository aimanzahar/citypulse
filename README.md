# FixMate — Flutter app + React dashboard (Codespaces-friendly)

FixMate is a lightweight, demo-friendly citizen maintenance reporter. It lets you quickly capture issues, geotag them, and visualize reports on a simple dashboard. There’s no backend; everything runs locally or in the browser — perfect for hackathons, prototypes, and GitHub Codespaces.

## Why this repo exists
- Zero-backend demo: data lives on-device (or in demo JSON for the dashboard).
- Deterministic "mock AI" categorization so UX flows are predictable.
- Fast setup in Codespaces or locally with minimal dependencies.

## Quick start in GitHub Codespaces

You can run both the Flutter app (as a web app) and the static React dashboard entirely inside a Codespace. No emulators required.

### 1) Flutter Web (recommended in Codespaces)
- Prerequisites: Flutter SDK is available in your Codespace. If not, install it or use a devcontainer with Flutter preinstalled. Then enable web:
  - flutter config --enable-web
- Install dependencies:
  - flutter pub get
- Run a local web server (Codespaces will auto-forward the port):
  - flutter run -d web-server --web-port 3000
- Open the forwarded port from the Codespaces ports panel. Camera and geolocation typically work over the Codespaces HTTPS tunneled URL.

Notes:
- Geolocation/camera require HTTPS in many browsers; Codespaces forwarded URLs are HTTPS, which helps.
- On web, images are stored as base64; on mobile, images are saved to app storage and paths persist (see [lib/services/storage.dart](lib/services/storage.dart:1)).
- Entry point for the app is [main()](lib/main.dart:8), which wires up i18n and the locale provider and launches [FixMateApp](lib/app.dart:12).

### 2) React dashboard (static site)
- Serve inside Codespaces (Python simple HTTP server):
  - cd dashboard && python -m http.server 8000
- Open the forwarded port and view your dashboard.

Behavior:
- Language toggle persists in localStorage.
- Filters drive a clustered Leaflet map, queue, drawer, stats, and optional heatmap overlay.

## Running locally (outside Codespaces)

### Flutter
- Install Flutter (stable) and run:
  - flutter pub get
  - flutter run  (or flutter run -d chrome)
- Android/iOS will prompt for camera and location permissions. On web, geolocation/camera require HTTPS; some browsers restrict camera on http.
- App root: [FixMateApp](lib/app.dart:12). Bottom tabs and routing live in [MainScreen](lib/app.dart:36) and the onboarding/start logic lives in [StartRouter](lib/app.dart:114).

### Dashboard
- Serve the dashboard folder over HTTP:
  - cd dashboard && python -m http.server 8000
- Open http://127.0.0.1:8000 (or your dev server URL).

## Features implemented
- Flutter app tabs: Report, Map, My Reports, Settings (bilingual EN/BM)
- Capture flow: camera/gallery, GPS, deterministic mock AI, local storage
- Map: OpenStreetMap via flutter_map with clustering, filters, marker details, legend, external maps link
- My Reports: list/detail with status cycle and delete
- Settings: language toggle and clear data
- React dashboard: filters, clustered map, queue, drawer, stats, heatmap toggle

## Project structure
- Key Flutter files:
  - [lib/app.dart](lib/app.dart:1)
  - [lib/main.dart](lib/main.dart:1)
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

## Tech stack
- Flutter packages: flutter_map, flutter_map_marker_cluster, latlong2, geolocator, image_picker, path_provider, shared_preferences, uuid, url_launcher, provider (see [pubspec.yaml](pubspec.yaml:31))
- Dashboard: React 18 UMD, Leaflet + markercluster (+ optional heat), Day.js

## Developer notes (for quick orientation)
- App entry: [main()](lib/main.dart:8) initializes locale/i18n and launches [FixMateApp](lib/app.dart:12).
- Tab nav and screens: [MainScreen](lib/app.dart:36) displays tabs for:
  - Report: [CaptureScreen](lib/screens/report_flow/capture_screen.dart:1)
  - Map: [MapScreen](lib/screens/map/map_screen.dart:1)
  - My Reports: [MyReportsScreen](lib/screens/my_reports/my_reports_screen.dart:1)
  - Settings: [SettingsScreen](lib/screens/settings/settings_screen.dart:1)
- Onboarding + welcome handoff: [StartRouter](lib/app.dart:114) decides whether to show onboarding or the main app.
- Themes live in [lib/theme/themes.dart](lib/theme/themes.dart:1), translations in [assets/lang/en.json](assets/lang/en.json:1) and [assets/lang/ms.json](assets/lang/ms.json:1).

## Known limitations
- No backend; all data is local or demo JSON.
- "AI" is simulated; severity/category are heuristic and not model-driven.
- Dashboard UI state is not persisted; a refresh resets filters and selections.
- OpenStreetMap tile usage is subject to their terms and rate limits.
- Mobile-only features (camera with native picker, GPS background behavior) won’t fully work in Codespaces; use Flutter Web inside Codespaces for best results.

## Visual tokens
- Severity colors: High #D32F2F, Medium #F57C00, Low #388E3C
- Status colors: Submitted #1976D2, In Progress #7B1FA2, Fixed #455A64

## Troubleshooting
- Browser blocks camera/geolocation on non-HTTPS:
  - Use Codespaces forwarded HTTPS URL or run locally over HTTPS.
- Flutter web server port not visible:
  - Check Codespaces “Ports” tab, ensure the port is “Public”.
- Slow map tile loads:
  - You may be rate-limited or on a constrained network; reduce panning/zoom or cache during demos.

## License
- Placeholder: add a LICENSE file or specify licensing before distribution.

## Acknowledgements
- OpenStreetMap, Leaflet, flutter_map and community plugins, React, Day.js, Flutter community.