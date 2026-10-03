import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:immortalwrt_app/widgets/traffic_icon.dart';

void main() {
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
