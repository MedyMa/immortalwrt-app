# ImmortalWrt Mobile: first release

## Scope

One standalone Flutter application for iOS and Android. At home it can read `192.168.2.1`; outside it uses the existing `https://bananapi.x.ddnsto.com` HTTPS tunnel, which was verified to forward `/ubus` JSON-RPC. No VPN, MiWiFi data, router configuration, or background collection.

## Screens

1. **Overview:** connection state and last update, current down/up rate, session usage, router uptime, and quick links to three details.
2. **Devices:** clients identified by the Traffic App, with current session usage and names/IPs. The UI does not call an address a Wi-Fi client unless the router reports that association.
3. **Wi-Fi:** MT7988 BE14 radio information from `network.wireless status`; show unsupported details as unavailable rather than inventing values.
4. **Traffic:** a history chart from `luci.traffic.getSeries`, traffic totals, and top applications from `getSummary`.
5. **Connection:** router URL, username, and password. Credentials are stored in OS secure storage. The app does not persist an ubus session ID after logout.

## Visual language

Light neutral canvas, dark ink text, blue for download, purple for upload, restrained green for online state. Important measurements have large numerals and their time scope next to them. Cards use consistent padding and minimum touch target sizes. Empty, stale, loading, and error states are explicit. Dark mode follows the system.

## Data and security

The client uses the router's existing ubus JSON-RPC endpoint. It logs in through `session.login` and reads only `luci.traffic.getSummary`, `getLive`, `getSeries`, `network.wireless.status`, and `system.info`. Each payload is validated separately; one unavailable service does not erase other data. No write RPC is called by the app. The account's permissions are determined by the router; a dedicated read-only account is recommended. The remote endpoint uses a trusted HTTPS certificate. Plain HTTP is permitted only for `192.168.2.1` and is clearly identified in the connection screen because credentials would cross the LAN without transport encryption.

## Delivery

GitHub Actions runs formatting, static analysis, tests, Android debug APK build, and unsigned iOS simulator build. An unsigned iOS artifact is for simulator/CI verification only; physical iPhone distribution needs Apple signing credentials and a separate release workflow.

## Acceptance

- iOS and Android navigate all screens without a router and show a useful offline state.
- With a reachable router, Traffic values agree with LuCI for the same session and timestamps.
- Missing Traffic App or Wi-Fi status produces a clear partial-data state.
- Network calls are read-only after login; passwords never appear in logs or committed files.
- CI publishes Android and iOS simulator artifacts on successful builds.
