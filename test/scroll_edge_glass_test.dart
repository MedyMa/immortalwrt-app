import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/widgets/scroll_edge_glass.dart';

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0; x < size.width; x += 8) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 4, size.height),
        Paint()..color = Colors.black,
      );
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble() + 4, 0, 4, size.height),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final reducedMotion in [false, true]) {
      for (final height in [24, 60]) {
        testWidgets(
          'actual backdrop stripes recover smoothly in $brightness motion=$reducedMotion height=$height',
          (tester) async {
            tester.view.physicalSize = const Size(200, 140);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reducedMotion),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: key,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _Stripes())),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: height.toDouble(),
                        child: ScrollEdgeGlass(
                          color: brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          statusHeight: height.toDouble(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final render =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final bytes = await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1);
              try {
                return await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
              } finally {
                image.dispose();
              }
            });
            int contrast(int y) =>
                (bytes!.getUint8((y * 200 + 80) * 4) -
                        bytes.getUint8((y * 200 + 84) * 4))
                    .abs();
            expect(
              contrast(0),
              lessThan(40),
              reason:
                  'Underlying stripes must really blur, not merely receive tint',
            );
            expect(contrast(height - 6), greaterThan(contrast(height - 20)));
            expect(contrast(height - 1), greaterThan(220));
            expect(contrast(height), 255);
            for (var y = 0; y < height + 4; y++) {
              expect(
                (contrast(y + 1) - contrast(y)).abs(),
                lessThan(25),
                reason: 'No sharp seam at y=$y',
              );
            }
          },
        );
      }
    }
  }
  testWidgets('high contrast top has no blur or opacity mask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const SizedBox(
            width: 200,
            height: 60,
            child: ScrollEdgeGlass(color: Colors.white, statusHeight: 60),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
