# BE14 Channel History Implementation Plan

> **For agentic workers:** Implement task by task, with a failing focused test before each production change.

**Goal:** Render real BE14 channel, width, link quality and 24-hour activity in the mobile Wi-Fi page.

**Architecture:** A router-side one-minute sampler derives rates from vendor and interface counters, retaining a bounded RAM history. Read-only ubus methods expose sanitized status and history. The Flutter Wi-Fi screen selects a band and renders only fields backed by valid samples.

**Tech Stack:** BusyBox shell/awk, rpcd jshn, Flutter/Dart, existing custom painters and test harness.

## Global constraints

- No Wi-Fi password, station MAC, raw `iwpriv` response, or DDnsto token in the mobile RPC payload.
- `iw survey` is unsupported on the observed driver. Never label vendor TX failures as airtime, interference, or retransmissions.
- History lives in `/tmp/traffic`, has a 24-hour cap, and survives phone app restarts but not router reboot.
- Missing counters produce gaps or unavailable fields, never zero-filled measurements.
- Preserve existing traffic collection and its CI gate.

---

### Task 1: Sanitized status

**Files:** `Luci-app/luci-app-traffic/root/usr/libexec/rpcd/luci.traffic`, `Luci-app/luci-app-traffic/tools/mobile-status-selftest.sh`.

- [ ] Extend the failing selftest to expect `htmode` and `ifname` from a BE14 fixture and to reject a fixture key.
- [ ] Run the selftest and confirm failure on the missing fields.
- [ ] Project only allowlisted `htmode` and interface name in `getWirelessStatus`.
- [ ] Run the selftest and existing rpcd selftest.

### Task 2: Router samples and history RPC

**Files:** `Luci-app/luci-app-traffic/root/usr/share/traffic/wifi-collector.sh`, `Luci-app/luci-app-traffic/root/etc/init.d/traffic`, `Luci-app/luci-app-traffic/root/usr/libexec/rpcd/luci.traffic`, `Luci-app/luci-app-traffic/root/usr/share/rpcd/acl.d/luci-app-traffic.json`, `Luci-app/luci-app-traffic/Makefile`, `Luci-app/luci-app-traffic/tools/wifi-history-selftest.sh`.

- [ ] Write a shell fixture for two counter samples, reset, missing stats, bounded history, and no secret fields; verify it fails.
- [ ] Add one-minute per-radio RAM sampling and atomic latest/history updates; compute TX failure %, RX CRC %, and RX/TX byte rates only from valid deltas.
- [ ] Add bounded read-only `getWirelessHistory` JSON and ACL; verify fixture, rpcd and package tests.
- [ ] Bump package version and run shell checks.

### Task 3: Flutter models and page

**Files:** `lib/models/router_models.dart`, `lib/services/router_api.dart`, `lib/screens/wifi.dart`, `test/router_models_test.dart`, `test/router_api_test.dart`, `test/widget_test.dart`.

- [ ] Add failing tests for channel width, missing versus zero metric, history gap, page-scoped RPC and selector behavior.
- [ ] Parse width from `htmode` and timestamps/metrics from the bounded history RPC.
- [ ] Build the approved band selector, quality and activity charts; omit unsupported occupancy/interference/client signal sections.
- [ ] Run format, analyze and all Flutter tests; update real-component preview fixture.

### Task 4: Integration

**Files:** Both READMEs and app preview screenshots.

- [ ] Compare the rendered screen with the approved mockup and verify small-screen scrolling.
- [ ] Run full CI-equivalent local gates, review the diff for secrets, commit and push both repositories.
- [ ] Confirm both GitHub Actions runs and report router installation/hardware validation separately.
