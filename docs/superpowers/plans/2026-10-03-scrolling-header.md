# Scrolling header implementation plan

Approved behavior: page titles and settings scroll away with content; system time and battery remain sharp above a bounded glass backdrop. Top color follows the page exactly in both appearances.

- [x] Move the toolbar into the scroll content, retaining settings accessibility and pull refresh.
- [x] Overlay only the system safe inset with page-colored glass at sigma 18; preserve accessibility opaque fallback.
- [x] Verify scrolling, theme color, status inset, existing widgets, and static analysis.
- [ ] Push the verified change and trigger mobile CI.

Verification: static analysis clean; 71 tests passed, including toolbar scrolling out of hit testing and a fixed 32 px status glass inset. Light and dark previews rendered from delivery components using sample data.
