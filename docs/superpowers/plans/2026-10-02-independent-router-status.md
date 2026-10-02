# Independent Router Status Implementation Plan

> Execute sequentially with regression gates before publishing.

**Goal:** Read BE14 and CPU through an independent router package and remove those responsibilities from traffic.

**Architecture:** `rpcd-mod-router-status` publishes the read-only `router.status` object. It owns its collector and `/tmp/router-status` history. Traffic keeps its existing data, RPC object, collector, UI and 24-hour default.

**Tech Stack:** Flutter/Dart, rpcd shell plugins, procd, jshn, AWK, OpenWrt SDK.

## Constraints

- Keep 1-second foreground rate polling and 24-hour traffic statistics.
- No wireless passwords, write RPCs, driver configuration commands or fabricated radio measurements.
- No dependency on traffic in the status package, its ACL, polling, or Wi-Fi session checks.
- Preserve existing flow statistics and persistent archives when upgrading.
- Use monotonic version increases; ship installation and device verification instructions.
- Hardware validation requires installing the new router package; host tests are not hardware proof.

## Steps

1. Add failing app and package boundary tests for independent status, missing traffic, denied ACL and expired sessions.
2. Move sanitized radio status, CPU counters, history sampling and tests to a standalone package with its own service, ACL, directory and SDK workflow.
3. Restore traffic RPC, service, ACL, packaging and documentation to their pre-monitoring behavior. Remove the added wireless files/tests; keep unrelated traffic improvements.
4. Switch the app to `router.status`; distinguish absent components from connection failures and use a system read for session checks.
5. Run the existing traffic suites, independent status suites, Flutter format/analyze/tests and real-component previews.
6. Publish router packages and mobile changes, verify CI artifacts, and document router installation plus a read-only hardware checklist.
