import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/services/traffic_icons.dart';

void main() {
  test('website index covers all entries beyond the old 256 cutoff', () {
    final rows = List.generate(
      300,
      (i) => 'site$i.com\tsite$i.com.png\t100',
    ).join('\n');
    final catalog = TrafficIcons.fromIndexes(
      Uri.parse('https://router.example.com'),
      '',
      '',
      rows,
    );
    expect(catalog.websites.length, 300);
    expect(
      catalog.iconUri('site299.com')?.path,
      '/traffic-site-icons/site299.com.png',
    );
  });
  test('website cache is same-origin and never overrides packaged artwork', () {
    final catalog = TrafficIcons.fromIndexes(
      Uri.parse('https://router.example.com'),
      'stripe\n',
      'stripe.com\tstripe\n',
      'comfylink.com\tcomfylink.com.png\nstarrydyn.com\tstarrydyn.com.ico\n'
          'stripe.com\tstripe.com.png\nevil.com\t../private.png\n',
    );
    expect(
      catalog.iconUri('comfylink.com')?.toString(),
      'https://router.example.com/traffic-site-icons/comfylink.com.png',
    );
    expect(
      catalog.iconUri('starrydyn.com')?.path,
      '/traffic-site-icons/starrydyn.com.ico',
    );
    expect(
      catalog.iconUri('stripe.com')?.path,
      '/luci-static/resources/traffic/icons/stripe.svg',
    );
    expect(catalog.iconUri('evil.com'), isNull);
  });
  test(
    'packaged names, protocol buckets and brand domains resolve locally',
    () {
      final catalog = TrafficIcons.fromIndexes(
        Uri.parse('https://router.example.com'),
        'uc-browser\nssl-tls\nhttp\nspeedtest-cn\ndeepseek\nstripe\n'
            'samsung\nplaystation5\n',
        'stripe.com\tstripe\n',
      );
      expect(
        catalog.iconUri('UC Browser')?.path,
        '/luci-static/resources/traffic/icons/uc-browser.svg',
      );
      expect(
        catalog.iconUri('SSL/TLS')?.path,
        '/luci-static/resources/traffic/icons/ssl-tls.svg',
      );
      expect(
        catalog.iconUri('speedtest.cn')?.path,
        '/luci-static/resources/traffic/icons/speedtest-cn.svg',
      );
      expect(
        catalog.iconUri('api.stripe.com')?.path,
        '/luci-static/resources/traffic/icons/stripe.svg',
      );
      expect(
        catalog.iconUri('samsungcloudcn.com')?.path,
        '/luci-static/resources/traffic/icons/samsung.svg',
      );
      expect(
        catalog.iconUri('PlayStation 5')?.path,
        '/luci-static/resources/traffic/icons/playstation5.svg',
      );
      expect(catalog.iconUri('unknown.invalid'), isNull);
    },
  );

  test('domain mapping cannot escape the packaged icon directory', () {
    final catalog = TrafficIcons.fromIndexes(
      Uri.parse('https://router.example.com'),
      'safe\n',
      'evil.com\t../safe\n',
    );
    expect(catalog.iconUri('evil.com'), isNull);
  });
}
