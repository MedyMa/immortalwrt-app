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
