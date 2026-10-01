# ImmortalWrt Mobile

An independent iOS and Android status app for the MT7988 router. It uses the existing `https://bananapi.x.ddnsto.com` endpoint outside the home and can use `192.168.2.1` locally, without a phone VPN.

The app shows router uptime, Traffic App rates and session totals, DHCP leases and traffic clients, and the BE14 radio status exposed by OpenWrt's `network.wireless status`. It does not display MiWiFi, modify router settings, or connect a VPN.

The overview uses a three-node device → MT7988 → Internet diagram. It is a topology sketch: the app verifies its MT7988 connection, but does not measure the upstream Internet link or claim that device records are currently online.

The four screens follow the [platform-adaptive v3 design](design/platform-adaptive-v3.md). iOS uses a native UIKit tab bar, which adopts the system's Liquid Glass appearance on supported OS versions. Android uses Material 3 navigation, Android 12+ system accent color, and a navigation rail on wider screens. The content remains the same read-only router data on both platforms.

| iOS preview | Android preview |
| --- | --- |
| [Overview](design/previews/ios-overview.png) · [Devices](design/previews/ios-devices.png) · [Wi-Fi](design/previews/ios-wifi.png) · [Traffic](design/previews/ios-traffic.png) | [Overview](design/previews/android-overview.png) · [Devices](design/previews/android-devices.png) · [Wi-Fi](design/previews/android-wifi.png) · [Traffic](design/previews/android-traffic.png) |

The previews render the shipped Flutter widgets with example data. The iOS previews use a Cupertino tab bar fallback because they were rendered on Windows; the actual UIKit Liquid Glass appearance must be checked in the iOS simulator.

## Connect

1. Install `luci-app-traffic` and ensure its collector is running on the router.
2. Open the app's connection screen. Its default HTTPS address is `https://bananapi.x.ddnsto.com`; the remote tunnel was checked to forward unauthenticated `/ubus` requests on 2026-10-01, but login and authorized methods still require a device-side test.
3. Enter the LuCI/ubus username and password. At home, `http://192.168.2.1` is an optional local fallback. The username is not prefilled so a dedicated read-only account can be used.

The app sends `session.login`, followed only by `luci.traffic.getSummary`, `getLive`, `getSeries`, `network.wireless.status`, `system.info`, and `luci-rpc.getDHCPLeases`. It never calls a router write method. Prefer a dedicated read-only ubus account, because a full administrator credential still grants administrator rights to anyone who obtains it. Credentials are stored in Android Keystore / iOS Keychain through `flutter_secure_storage`; logout deletes them. The ubus session stays in memory.

The local `http://192.168.2.1` connection is **not encrypted**. Only this exact IP is permitted over HTTP in the app and platform network policy. The DDnsto HTTPS route provides remote connectivity without a phone VPN; it depends on that third-party tunnel being online. Use a dedicated read-only router account if available.

Device rows combine DHCP leases with devices that have traffic in the current collection session; neither proves a device is currently online. The session WAN counter and identified-application totals have different scopes; the UI labels them separately. Vendor BE14 radios may not appear in standard `network.wireless status` on some firmware builds; the app then shows an unavailable state instead of invented values.

Only the visible page is polled. Polling pauses while the app is in the background and resumes immediately when it returns to the foreground. An expired ubus session is reauthenticated once from secure storage, then the read is retried. If the second read is still denied, the app reports a likely ACL issue and stops automatic login attempts. DNS, TLS, timeout, HTTP and ubus permission errors have separate messages. Failed sections keep their previous data with an explicit error label.

## Development

Flutter 3.47.5 is used by CI:

```sh
flutter pub get
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter run
```

CI compiles against **Android 17 SDK (API 37)** with Android Gradle Plugin 9.1.1. `targetSdk` still follows Flutter's default pending Android 17 device behavior testing. The iOS job explicitly uses the **Xcode 27 / iOS 27 SDK** runner while retaining iOS 15 as its deployment target. CI prints the selected SDK versions. The Android artifact is a **debug APK**. The iOS artifact is an **unsigned simulator app**; it cannot be installed on a physical iPhone. iPhone distribution requires Apple signing credentials and a later signed release workflow.
