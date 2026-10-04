import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/services/traffic_icons.dart';

void main() {
  test(
    'static SVG cache stays same-origin with version and rejects other files',
    () {
      final icons = TrafficIcons.fromIndexes(
        Uri.parse('https://router.example.com'),
        '',
        '',
        'vector.com\tvector.com.svg\t123\nwrong.com\tvector.com.svg\n'
            'evil.com\tevil.com.html\n',
      );
      expect(
        icons.iconUri('vector.com')?.toString(),
        'https://router.example.com/traffic-site-icons/vector.com.svg?v=123',
      );
      expect(icons.iconUri('wrong.com'), isNull);
      expect(icons.iconUri('evil.com'), isNull);
    },
  );
  test('website cache chooses exact then closest safe parent', () {
    final catalog = TrafficIcons.fromIndexes(
      Uri.parse('https://router.example.com'),
      'stripe\n',
      'stripe.com\tstripe\n',
      'example.com\texample.com.png\t1\n'
          'api.example.com\tapi.example.com.ico\t2\n'
          'example.co.uk\texample.co.uk.png\nco.uk\tco.uk.png\n'
          'com.cn\tcom.cn.png\nexample.com.cn\texample.com.cn.png\n'
          'unknown.xyz\tunknown.xyz.png\n'
          'github.io\tgithub.io.png\nstripe.com\tstripe.com.png\n',
    );
    expect(
      catalog.iconUri('api.example.com')?.path,
      '/traffic-site-icons/api.example.com.ico',
    );
    expect(catalog.iconUri('v1.api.example.com')?.query, 'v=2');
    expect(
      catalog.iconUri('www.example.com')?.path,
      '/traffic-site-icons/example.com.png',
    );
    expect(
      catalog.iconUri('api.example.co.uk')?.path,
      '/traffic-site-icons/example.co.uk.png',
    );
    expect(
      catalog.iconUri('api.example.com.cn')?.path,
      '/traffic-site-icons/example.com.cn.png',
    );
    expect(catalog.iconUri('api.unrelated.co.uk'), isNull);
    expect(catalog.iconUri('api.unrelated.com.cn'), isNull);
    expect(catalog.iconUri('api.unknown.xyz'), isNull);
    expect(catalog.iconUri('tenant.github.io'), isNull);
    expect(
      catalog.iconUri('api.stripe.com')?.path,
      '/luci-static/resources/traffic/icons/stripe.svg',
    );
  });
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
