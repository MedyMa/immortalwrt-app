# Device records

- Bundle brand SVGs locally; no icon downloads or new router RPCs.
- Use explicit hostname tokens for brand and broad device type. Unknown names
  retain a generic icon. Names are not proof of online state or exact model.
- The owner confirmed that `XiaoQiang` is their Xiaomi AX9000. This exact,
  case-insensitive name has a confirmed mapping. Other Xiaomi devices are not
  assigned this model. Update the mapping if the device using this name changes.
- Show type and IP below the original name. The confirmed model appears beside
  the name. Details expose the full name, IP, MAC, record sources, traffic and
  identification basis, with selectable values.
- Brand marks use the current foreground colour for system light/dark mode.
  Generic icons use SF Symbols on iOS and Material icons on Android.
- SVG provenance and upstream licence references are preserved in
  `assets/device-brands/sources.json`, copied from the local traffic icon catalogue.
  Synology's background was removed and its view box cropped to the wordmark;
  unused stylesheet elements were removed for Flutter SVG compatibility.

## Approved detail sheet (2026-10-03)

The compact detail sheet lives in `lib/widgets/device_detail_sheet.dart`.
It shows the brand icon, selectable original name and identity subtitle, then
session traffic and selectable IP/MAC rows. Source records remain visible;
identification evidence is collapsed initially. It supports close, scrim and
drag dismissal. System colours and the full glass treatment remain enabled.
Close and disclosure use Cupertino controls and SF Symbols on iOS, Material
controls on Android. Height is bounded to 85 percent of the screen; narrow
screens or large text stack the detail labels above their values and allow
scrolling. It does not add router calls or dependencies.
