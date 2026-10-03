part of '../main.dart';

/// Bounded chrome blur; live status cards remain opaque.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.blur = true,
    this.border = true,
  });

  final Widget child;
  final BorderRadius radius;
  final bool blur;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final opaque = !blur || media.highContrast || media.disableAnimations;
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
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: surface,
            ),
    );
  }
}
