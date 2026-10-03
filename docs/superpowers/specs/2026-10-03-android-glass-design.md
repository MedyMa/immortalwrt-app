# Android glass surfaces

Approved in chat: frosted navigation, toolbar actions and connection sheet; opaque readable data cards; coherent light/dark appearance and Material expressive selection feedback.

Use Flutter's bounded BackdropFilter for Android chrome, with system-seeded colors. This is an application treatment inspired by Material 3 Expressive, not a claim that Flutter renders native Compose components. Keep UIKit iOS chrome. No API, permission, polling or router changes.

Floating navigation has a 28 dp radius and 72 dp bar. Scroll content continues underneath, with bottom padding to keep the last item accessible. Toolbar blurs only its own bounds. Settings uses a 48 dp touch target. Connection sheet uses a 28 dp top radius and filled readable fields; its controls remain usable with the keyboard open.

High contrast disables translucency. Reduced motion disables blur and navigation animation. Do not blur individual data cards or animate live figures.

Acceptance: all four tabs and settings work; short pages still pull-refresh; no overflow at phone/tablet widths or larger text; light/dark real Flutter renders; existing session tests pass; Android and iOS compile in CI.
