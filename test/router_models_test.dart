import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/models/router_models.dart';

void main() {
  test('traffic headline uses WAN interface totals, not attributed totals', () {
    final summary = TrafficSummary.fromJson({
      'collected_at': 1720000000,
      'iface': {'down': 1000, 'up': 300, 'dev': 'br-wan'},
      'totals': {'down': 100, 'up': 40, 'client_count': 2},
      'clients': [
        {'ip': '192.168.2.10', 'name': 'Phone', 'bytes': 90},
      ],
      'apps': [
        {'name': 'Video', 'down': 70, 'up': 20},
      ],
    });

    expect(summary.headlineDown, 1000);
    expect(summary.headlineUp, 300);
    expect(summary.attributedDown, 100);
    expect(summary.clients.single.name, 'Phone');
    expect(summary.headlineSource, 'br-wan');
  });

  test('missing sections remain unavailable instead of invented', () {
    final summary = TrafficSummary.fromJson({'totals': {}});
    expect(summary.hasWanTotals, isFalse);
    expect(summary.collectedAt, isNull);
    expect(summary.clients, isEmpty);
  });

  test('series point bytes convert to bytes per second', () {
    final series = TrafficSeries.fromJson({
      'interval': 10,
      'points': [
        [1720000000, 1000, 200, 0, 0, 0],
      ],
    });
    expect(series.points.single.downBytesPerSecond, 100);
    expect(series.points.single.upBytesPerSecond, 20);
  });

  test('wireless status reads radio state without claiming association', () {
    final radios = WifiRadio.parseAll({
      'radio0': {
        'up': true,
        'interfaces': [
          {
            'config': {'ssid': 'BE14-Home'},
            'ifname': 'ra0'
          },
        ],
      },
    });
    expect(radios.single.name, 'radio0');
    expect(radios.single.ssids, ['BE14-Home']);
    expect(radios.single.clientCount, isNull);
  });

  test('DHCP leases are labeled without claiming online status', () {
    final devices = DhcpDevice.parseAll({
      'dhcp_leases': [
        {'hostname': 'Phone', 'ipaddr': '192.168.2.10', 'macaddr': 'AA:BB'},
        {'hostname': '*', 'ipaddr': '192.168.2.11', 'macaddr': 'CC:DD'},
      ],
    });
    expect(devices.map((item) => item.name), ['Phone', '192.168.2.11']);
    expect(devices.first.mac, 'AA:BB');
  });
}
