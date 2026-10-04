import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:immortalwrt_app/widgets/traffic_icon.dart';

void main() {
  testWidgets('oversized or failed cached SVG loads retain website fallback', (
    tester,
  ) async {
    for (final oversized in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrafficIcon(
              key: ValueKey(oversized),
              name: 'vector.com',
              uri: Uri.parse(
                'https://router.example.com/traffic-site-icons/vector.com.svg',
              ),
              load: (_) async {
                if (oversized) return Uint8List(65537);
                throw StateError('failed transfer');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VE'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('cached SVG uses bounded loader and renders on both appearances', (
    tester,
  ) async {
    var calls = 0;
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: TrafficIcon(
              key: ValueKey(brightness),
              name: 'vector.com',
              uri: Uri.parse(
                'https://router.example.com/traffic-site-icons/vector.com.svg?v=1',
              ),
              load: (_) async {
                calls++;
                return Uint8List.fromList(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><path fill="#123abc" d="M0 0h32v32H0z"/></svg>'
                      .codeUnits,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(calls, 2);
  });
  testWidgets('Apple Maps and Siri use compatible bundled artwork', (
    tester,
  ) async {
    for (final name in ['Apple Maps', 'Siri']) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: TrafficIcon(name: name)),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<AssetImage>());
        expect(
          (image.image as AssetImage).assetName,
          'assets/traffic-icons/${name == 'Siri' ? 'siri' : 'apple-maps'}.png',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
  test('ICO decoding produces a bounded PNG for both mobile platforms', () {
    final ico = img.encodeIco(img.Image(width: 32, height: 32));
    final png = decodeTrafficIcon(Uint8List.fromList(ico));
    expect(png, isNotNull);
    expect(img.decodePng(png!)!.width, lessThanOrEqualTo(64));
    expect(
      decodeTrafficIcon(Uint8List.fromList('<html>error</html>'.codeUnits)),
      isNull,
    );
    expect(decodeTrafficIcon(Uint8List(65537)), isNull);
  });
  testWidgets('two-letter website fallback follows system brightness', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(body: TrafficIcon(name: 'comfylink.com')),
        ),
      );
      expect(find.text('CO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('offscreen cached raster loads only after scrolling into view', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 1000),
                TrafficIcon(
                  name: 'starrydyn.com',
                  uri: Uri.parse(
                    'https://router.example.com/traffic-site-icons/starrydyn.com.ico',
                  ),
                  load: (_) async {
                    calls++;
                    return null;
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('ST'), findsOneWidget);
  });
}
