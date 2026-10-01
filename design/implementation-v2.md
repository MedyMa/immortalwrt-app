# Mobile v2 Implementation Plan

**Goal:** Ship the approved v2 UI with reliable read-only remote status on Android 17 and iOS 27 SDKs.

**Architecture:** Keep ubus transport in `services/router_api.dart`; define a section-specific read policy and typed failures. The app shell owns lifecycle, secure credentials, refresh scheduling and snapshots. Screen and shared widget files remain presentation-only.

**Tech stack:** Flutter 3.47.5, Dart, `http`, `flutter_secure_storage`, Android API 37, Xcode 27 / iOS 27 SDK.

## Tasks

- [x] Add transport tests for session expiry, one re-login, permission rejection, DNS/TLS/HTTP classification, partial series errors and section request sets.
- [x] Implement typed ubus errors, section-specific fetch and snapshot merging; verify tests.
- [x] Add widget/lifecycle tests for background pause, resume refresh and section switching; implement shell state machine.
- [x] Split `main.dart` into `screens/`, `widgets/`, `services/`, `models/` while preserving the rendered v2 UI and existing tests.
- [x] Pin Android compile SDK 37 and Xcode 27 CI image, print tool versions and document signing limits.
- [x] Run format, analyze, full Flutter tests, inspect Git diff, commit/push, verify both GitHub Actions jobs and artifacts. Both jobs succeeded in [CI run 36807475862](https://github.com/MedyMa/immortalwrt-app/actions/runs/36807475862).

No router write RPCs, background collection, MiWiFi data or VPN are introduced.
