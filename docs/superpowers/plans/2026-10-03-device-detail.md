# Device detail card implementation plan

Use executing-plans to implement the approved preview in this session.

**Goal:** Replace the verbose device detail sheet with the approved compact card on Android and iOS.

**Architecture:** Keep the existing read-only data and device identity model. Use a separate stateful detail sheet within the current Dart library for disclosure state. Retain the shared glass surface and system brightness colours; use native-style close and disclosure icons.

## Approved design

Brand icon and original device name head the sheet. Brand, confirmed model and type appear beneath. A session traffic card precedes selectable IP/MAC and record-source rows. Identification evidence is collapsed initially. Closing, scrim dismissal and dragging remain available. Height is bounded and content can scroll at larger text sizes. Unknown values display a dash or "not provided", never a fabricated value.

## Steps

- [x] Update device widget tests for collapsed evidence, disclosure and close. Run to demonstrate failure against the old sheet.
- [x] Implement `lib/widgets/device_detail_sheet.dart`; connect from `screens/devices.dart` through `main.dart`.
- [x] Verify long IPv6, large text, both platforms and both brightness modes. Rerender the approved preview from the delivered components.
- [x] Run format, analysis, tests and diff checks; bump version, commit and push; verify CI starts.
