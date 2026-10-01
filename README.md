# ImmortalWrt Mobile

An independent iOS and Android status app for the MT7988 router. It uses the existing `https://bananapi.x.ddnsto.com` endpoint outside the home and can use `192.168.2.1` locally, without a phone VPN.

The first release shows router uptime, Traffic App rates and session totals, traffic clients/apps, and the BE14 radio status exposed by OpenWrt's `network.wireless status`. It does not display MiWiFi, modify router settings, or connect a VPN.

## Connect

1. Install `luci-app-traffic` and ensure its collector is running on the router.
2. Open the app's connection screen. Its default HTTPS address is `https://bananapi.x.ddnsto.com`; the remote tunnel was checked to forward unauthenticated `/ubus` requests on 2026-10-01, but login and authorized methods still require a device-side test.
3. Enter the LuCI/ubus username and password. At home, `http://192.168.2.1` is an optional local fallback.

The app sends `session.login`, followed only by `luci.traffic.getSummary`, `getLive`, `getSeries`, `network.wireless.status`, `system.info`, and `luci-rpc.getDHCPLeases`. It never calls a router write method. Prefer a dedicated read-only ubus account, because a full administrator credential still grants administrator rights to anyone who obtains it. Credentials are stored in Android Keystore / iOS Keychain through `flutter_secure_storage`; logout deletes them. The ubus session stays in memory.

The local `http://192.168.2.1` connection is **not encrypted**. Only this exact IP is permitted over HTTP in the app and platform network policy. The DDnsto HTTPS route provides remote connectivity without a phone VPN; it depends on that third-party tunnel being online. Use a dedicated read-only router account if available.

Device rows combine DHCP leases with devices that have traffic in the current collection session; neither proves a device is currently online. The session WAN counter and identified-application totals have different scopes; the UI labels them separately. Vendor BE14 radios may not appear in standard `network.wireless status` on some firmware builds; the app then shows an unavailable state instead of invented values.

## Development

Flutter 3.47.5 is used by CI:

```sh
flutter pub get
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter run
```

See [design](docs/design.md) for the screen and data contract. The Android artifact is a **debug APK**. The iOS artifact is an **unsigned simulator app**; it cannot be installed on a physical iPhone. iPhone distribution requires Apple signing credentials and a later signed release workflow.
