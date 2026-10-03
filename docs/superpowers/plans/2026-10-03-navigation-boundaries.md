# Navigation gesture boundary repair

Requirement: hide on upward swipe, restore only when scrolling back to the page top.

Confirmed failure: Android clamping scroll physics sends OverscrollNotification on short pages and at the bottom. The existing handler listened only to ScrollUpdateNotification and treated zero scroll position as a reason to show navigation regardless of direction.

Fix: consume user drag deltas from both notification types; retain the 12 logical pixel upward threshold. Restore on negative movement only when the top is reached, including inertial movement. Keep notifier-driven chrome updates and full glass effects.

Verification: failing tests reproduced short-page hiding and early restoration; after the fix all 26 widget tests passed. Full analysis and suite run before publishing.
