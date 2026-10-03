# ImmortalWrt Mobile

An independent iOS and Android status app for the MT7988 router. It uses the existing `https://bananapi.x.ddnsto.com` endpoint outside the home and can use `192.168.2.1` locally, without a phone VPN.

The app shows router uptime, CPU and memory usage, SFP link speeds, Traffic App rates and session totals, DHCP leases and traffic clients, and BE14 radio status. It does not display MiWiFi, modify router settings, or connect a VPN.

The overview uses a three-node device → MT7988 → Internet diagram. It is a topology sketch: the app verifies its MT7988 connection, but does not measure the upstream Internet link or claim that device records are currently online.

The four screens follow the [platform-adaptive v3 design](design/platform-adaptive-v3.md). iOS uses a native UIKit tab bar, which adopts the system's Liquid Glass appearance on supported OS versions. Android uses Material 3 navigation, Android 12+ system accent color, and a navigation rail on wider screens. The content remains the same read-only router data on both platforms.

Android uses a seamless page-colored header, compact capsule navigation and a frosted connection sheet, with opaque status cards. Navigation hides on upward swipes and returns on downward swipes; hidden items cannot receive touch, screen-reader or keyboard focus. Blur is disabled while scrolling, in high contrast and with reduced motion. Android configuration events and a resume-time native appearance read keep the app in sync with system dark mode. This remains a Flutter treatment, not native Compose components. [Night preview](design/previews/android-night.png) · [Connection sheet](design/previews/android-settings.png).

| iOS preview | Android preview |
| --- | --- |
| [Overview](design/previews/ios-overview.png) · [Devices](design/previews/ios-devices.png) · [Wi-Fi](design/previews/ios-wifi.png) · [Traffic](design/previews/ios-traffic.png) | [Overview](design/previews/android-overview.png) · [Devices](design/previews/android-devices.png) · [Wi-Fi](design/previews/android-wifi.png) · [Traffic](design/previews/android-traffic.png) |

The previews render the shipped Flutter widgets with example data. Golden tests block HTTP, so the Traffic preview shows initial avatars; on a connected device the app loads SVGs from the router's packaged icon directory. The iOS previews use a Cupertino tab bar fallback because they were rendered on Windows; the actual UIKit Liquid Glass appearance must be checked in the iOS simulator.

The Wi-Fi history card also has scrolled [Android](design/previews/android-wifi-detail.png) and [iOS](design/previews/ios-wifi-detail.png) previews. Their curves are example data used only for layout review.

## Connect

1. Install `rpcd-mod-router-status` for CPU, BE14 and wireless history. Install `luci-app-traffic` for flow statistics and `luci-app-sfp-status` for SFP details. These packages operate independently; the wireless sampler does not need traffic to be installed or running.
2. Open the app's connection screen. Its default HTTPS address is `https://bananapi.x.ddnsto.com`; the remote tunnel was checked to forward unauthenticated `/ubus` requests on 2026-10-01, but login and authorized methods still require a device-side test.
3. Enter the LuCI/ubus username and password. At home, `http://192.168.2.1` is an optional local fallback. The username is not prefilled so a dedicated read-only account can be used.

The app sends `session.login`, followed only by `luci.traffic.getSummary`, `getLive`, `getHourly`, `getSeries`, `router.status.getSystemMetrics`, `router.status.getWirelessStatus`, `router.status.getWirelessHistory`, `luci.sfp-status.getStatuses`, `system.info`, and `luci-rpc.getDHCPLeases`. It never calls a router write method. `router.status.getWirelessStatus` filters the netifd payload on the router so configured Wi-Fi passwords are never returned to the phone. Prefer a dedicated read-only ubus account, because a full administrator credential still grants administrator rights to anyone who obtains it. Credentials are stored in Android Keystore / iOS Keychain through `flutter_secure_storage`; logout deletes them. The ubus session stays in memory.

The local `http://192.168.2.1` connection is **not encrypted**. Only this exact IP is permitted over HTTP in the app and platform network policy. The DDnsto HTTPS route provides remote connectivity without a phone VPN; it depends on that third-party tunnel being online. Use a dedicated read-only router account if available.

Device rows combine DHCP leases with devices that have traffic in the current collection session; neither proves a device is currently online. The session WAN counter and identified-application totals have different scopes; the UI labels them separately. CPU usage is calculated from two `/proc/stat` samples, so the first screen briefly shows a sampling state. SFP status is read from `luci-app-sfp-status` and shown by the module's reported slot, without guessing which port is WAN. The Traffic page loads packaged SVG icons from the same router origin and falls back to an initial where artwork is unavailable.

Only the visible page is polled. Polling pauses while the app is in the background and resumes immediately when it returns to the foreground. An expired ubus session is reauthenticated once from secure storage, then the read is retried. If the second read is still denied, the app reports a likely ACL issue and stops automatic login attempts. DNS, TLS, timeout, HTTP and ubus permission errors have separate messages. Failed sections keep their previous data with an explicit error label.

The Wi-Fi page shows the reported BE14 channel and EHT width. Its 24-hour history uses one-minute counter samples, reduced to five-minute points for transfer. TX failure and RX CRC come from consecutive vendor-driver counters; download and upload rates come from AP-interface byte counters. This driver did not provide `nl80211` survey data or a usable station list, so airtime occupancy and client signal distribution are omitted. History lives in router RAM and starts anew after a reboot or package upgrade.

## Development

Signed iPhone/TestFlight delivery uses the manual `Publish iOS to TestFlight` workflow. See [publishing setup](docs/testflight.md) for the required signing secrets and App Store Connect app record.

Launcher artwork uses the approved router/network design. Android includes adaptive and monochrome resources with light/dark colors; iOS includes Any, Dark and Tinted variants. Sources are in `design/app-icons`; regenerate PNG assets with `tools/generate-app-icons.ps1` on Windows with Chrome installed.

Flutter 3.47.5 is used by CI:

```sh
flutter pub get
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter run
```

CI compiles against **Android 17 SDK (API 37)** with Android Gradle Plugin 9.1.1. `targetSdk` still follows Flutter's default pending Android 17 device behavior testing. The iOS job explicitly uses the **Xcode 27 / iOS 27 SDK** runner while retaining iOS 15 as its deployment target. CI prints the selected SDK versions. The Android artifact is a **debug APK**. The iOS artifact is an **unsigned simulator app**; it cannot be installed on a physical iPhone. iPhone distribution requires Apple signing credentials and a later signed release workflow.

## Refresh and backend compatibility

Temperature figures require `rpcd-mod-router-status` 0.1.2 or newer. CPU temperatures use labelled CPU/SoC thermal zones; disks use NVMe/drivetemp hwmon readings when the firmware exposes them. BE14 temperature reuses the existing one-minute driver sample. Each category shows the highest fresh reading, expiring after 180 seconds; absent, invalid or failed readings show a dash. SFP rows use the module Celsius field from the existing SFP API, alongside link speed. The app follows the system light/dark appearance.

Overview also reads `luci.turboacc.getMTKPPEStat` about every 15 seconds. Each PPE row uses turboacc's `BIND_PPE` / `ALL_PPE` counters; the percentage has the same scope as the local turboacc page. These are hardware flow-table entries, not unique devices or CPU load. Missing counters or invalid denominators stay unknown. Read-only accounts need the turboacc read ACL; no write permission is required. If turboacc is unavailable, other overview data remains usable.

Overview reads live rate every 1 second, with system status about every 15 seconds. Requests do not overlap. The Traffic page sums the latest 24 hourly buckets and loads the 24-hour minute series; session totals on Overview stay separate. Missing WAN buckets are labelled attributed totals instead of complete WAN totals.

BE14, CPU and wireless history require the independent rpcd-mod-router-status package. Traffic statistics alone use luci-app-traffic; neither Wi-Fi reads nor wireless sampling depend on it. Install the status package first, update the mobile app, then upgrade traffic to 1.1.7 to remove the misplaced monitoring methods. Reconnect after rpcd restarts. Dedicated read-only accounts require the router-status read ACL. The LuCI traffic page keeps its 24-hour default.

Router installation and device checks: https://github.com/MedyMa/luci-app/tree/main/Luci-app/rpcd-mod-router-status
