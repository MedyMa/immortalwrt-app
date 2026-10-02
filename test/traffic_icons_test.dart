import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/services/traffic_icons.dart';

void main() {
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
