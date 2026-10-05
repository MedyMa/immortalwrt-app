part of '../main.dart';

class _TopScrollEdgeGlass extends StatelessWidget {
  const _TopScrollEdgeGlass({super.key});

  @override
  Widget build(BuildContext context) => ScrollEdgeGlass(
    color: _pageOf(context),
    statusHeight: MediaQuery.viewPaddingOf(context).top,
  );
}

/// Keep the status area in the page's color space. UIKit's systemMaterial
/// supplies an independent tint which makes a strip above the Flutter page.
/// Shared page blur beneath the system status area and Android navigation.
class _StatusBarGlass extends StatelessWidget {
  const _StatusBarGlass({
    super.key,
    this.child = const SizedBox.expand(),
    this.radius,
  });

  final Widget child;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: _pageOf(context).withValues(
          alpha: highContrast ? 1 : (_isDark(context) ? 0.16 : 0.12),
        ),
      ),
      child: child,
    );
    // Reduce Motion affects transitions, not the transparency of static chrome.
    final glass = highContrast
        ? surface
        : BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _NavigationGeometry.blurSigma,
              sigmaY: _NavigationGeometry.blurSigma,
            ),
            child: surface,
          );
    return radius == null
        ? ClipRect(child: glass)
        : ClipRRect(borderRadius: radius!, child: glass);
  }
}

/// Bounded chrome blur; live status cards remain opaque.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(28)),
  });

  final Widget child;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final opaque = media.highContrast || media.disableAnimations;
    final dark = _isDark(context);
    final tint = Color.alphaBlend(
      Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: dark ? 0.055 : 0.025),
      _cardOf(context),
    );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(
          alpha: opaque
              ? 1
              : dark
              ? 0.9
              : 0.82,
        ),
        borderRadius: radius,
        border: Border.all(
          color: dark ? const Color(0xFF424854) : const Color(0xEEFFFFFF),
          width: 0.8,
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: radius,
      child: opaque
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _NavigationGeometry.blurSigma,
                sigmaY: _NavigationGeometry.blurSigma,
              ),
              child: surface,
            ),
    );
  }
}

class _ScrollingToolbar extends StatelessWidget {
  const _ScrollingToolbar({required this.title, required this.onSettings});
  final String title;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('scrolling-toolbar'),
    color: _pageOf(context),
    child: SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _inkOf(context),
                ),
              ),
            ),
          ),
          _SettingsAction(onPressed: onSettings),
        ],
      ),
    ),
  );
}
