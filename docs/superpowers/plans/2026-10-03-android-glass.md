# Android glass implementation plan

**Goal:** Implement the approved glass chrome while keeping router status readable.

**Architecture:** A shared bounded glass widget in `lib/widgets/glass.dart`, integrated by `lib/main.dart` and `lib/widgets/shared.dart`. Preserve the existing iOS UIKit bridge and data layer.

**Tech stack:** Flutter Material 3, dart:ui ImageFilter. No new dependencies.

- [x] Add glass surface with high-contrast/reduced-motion opaque fallback, 18 sigma bounded blur and light/dark tint.
- [x] Integrate toolbar, floating Android navigation and sheet; reserve scroll space and retain pull refresh.
- [x] Style settings action, filled fields and selected navigation with system colors and short animation.
- [x] Run format, analyze, full tests and render the delivery components with sample data in light/dark modes. Check sheet keyboard and navigation visibility.
- [x] Bump version, commit, push and verify Android/iOS build jobs.

Verification: Flutter analyze clean; 68 tests pass; phone light/dark, four tabs and keyboard sheet rendered from delivery widgets. Review fixes include tablet toolbar inset and pull-refresh feedback offset. CI result tracked in Actions.
