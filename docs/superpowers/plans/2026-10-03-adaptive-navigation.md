# Adaptive navigation and appearance

User approved: follow system dark mode; seamless page-colored header without glass frame; compact capsule navigation based on the supplied image, hidden on upward swipe and restored on downward swipe.

Investigation: current ThemeMode.system responds correctly to Flutter brightness in a host test. The device failure is not reproduced; add Android uiMode events and a resume-time native appearance read to cover missed/stale engine notifications, without claiming hardware proof.

Implementation: keep native appearance synchronization in MainActivity and app state; bound filter sigma to 8, use opaque navigation while scrolling, remove toolbar/gear filters. Use ValueNotifiers for navigation scroll feedback so gestures do not rebuild data pages. Preserve navigation space, show at top/tab changes/settings/resume, disable hiding for assistive navigation. Keep iOS native chrome.

Verify: live system brightness, resume with stale Flutter brightness, native events, swipe directions, semantic/hit-test hiding, keyboard sheet, full suite, day/night preview and platform CI builds.
