part of '../main.dart';

/// Bounded chrome blur; live status cards remain opaque.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.border = true,
    this.surfaceColor,
  });

  final Widget child;
  final BorderRadius radius;
  final bool border;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final opaque = media.highContrast || media.disableAnimations;
    final dark = _isDark(context);
    final tint =
        surfaceColor ??
        Color.alphaBlend(
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
        border: border
            ? Border.all(
                color: dark ? const Color(0xFF424854) : const Color(0xEEFFFFFF),
                width: 0.8,
              )
            : null,
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
