import 'dart:ui';
import 'package:flutter/material.dart';

/// Status-area blur fades into unobstructed scrolling content below it.
class ScrollEdgeGlass extends StatelessWidget {
  const ScrollEdgeGlass({
    super.key,
    required this.color,
    required this.statusHeight,
  });
  final Color color;
  final double statusHeight;
  static const fadeHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    if (highContrast) return ColoredBox(color: color);
    final tint = color.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
    );
    Widget surface() => DecoratedBox(decoration: BoxDecoration(color: tint));
    final solidHeight = (statusHeight - fadeHeight / 2).clamp(
      0.0,
      statusHeight,
    );
    final filter = ImageFilter.blur(sigmaX: 18, sigmaY: 18);
    // Skia cannot reuse a backdrop captured outside ShaderMask's saveLayer.
    // Modulate the filtered image itself there, so it still composites over
    // the original page instead of an empty isolated layer.
    if (!ImageFilter.isShaderFilterSupported) {
      const bands = 12;
      return LayoutBuilder(
        builder: (context, constraints) {
          final transitionHeight = constraints.maxHeight - solidHeight;
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: solidHeight,
                child: ClipRect(
                  child: BackdropFilter(filter: filter, child: surface()),
                ),
              ),
              for (var i = 0; i < bands; i++)
                Positioned(
                  top: solidHeight + transitionHeight * i / bands,
                  left: 0,
                  right: 0,
                  height: transitionHeight / bands,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.compose(
                        outer: ColorFilter.mode(
                          Colors.white.withValues(alpha: 1 - (i + 0.5) / bands),
                          BlendMode.modulate,
                        ),
                        inner: filter,
                      ),
                      child: ColoredBox(
                        color: tint.withValues(
                          alpha: tint.a * (1 - (i + 0.5) / bands),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
    // Capture the original backdrop before the mask's isolated layer. Both
    // disjoint regions reuse that capture instead of blurring a transparent
    // buffer or repeatedly sampling an already blurred status area.
    return BackdropGroup(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: solidHeight,
            child: ClipRect(
              child: BackdropFilter.grouped(filter: filter, child: surface()),
            ),
          ),
          Positioned(
            top: solidHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                ).createShader(bounds),
                child: BackdropFilter.grouped(
                  blendMode: BlendMode.src,
                  filter: filter,
                  child: surface(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
