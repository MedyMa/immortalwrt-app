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
            'ifname': 'ra0',
          },
        ],
      },
    });
    expect(radios.single.name, 'radio0');
    expect(radios.single.ssids, ['BE14-Home']);
    expect(radios.single.clientCount, isNull);
  });

  test('BE14 radios keep reported bands and channels without passwords', () {
    final radios = WifiRadio.parseAll({
      'MT7990_1_1': {
        'up': true,
        'config': {'band': '2g', 'channel': '3'},
        'interfaces': [
          {
            'config': {'ssid': 'Home-2G'},
          },
        ],
      },
      'MT7990_1_2': {
        'up': true,
        'config': {'band': '5g', 'channel': '40'},
        'interfaces': [
          {
            'config': {'ssid': 'Home-5G'},
          },
        ],
      },
      'MT7990_2': {
        'up': true,
        'config': {'band': '6g', 'channel': '37'},
        'interfaces': [
          {
            'config': {'ssid': 'Home-6G'},
          },
        ],
      },
    });
    expect(radios.map((radio) => radio.band), ['2g', '5g', '6g']);
    expect(radios.map((radio) => radio.channel), [3, 40, 37]);
    expect(radios.every((radio) => radio.up), isTrue);
  });

  test('BE14 sanitized radio and sampled history retain actual fields', () {
    final radio = WifiRadio.parseAll({
      'radios': [
        {
          'name': 'MT7990_1_2',
          'up': true,
          'band': '5g',
          'channel': '40',
          'htmode': 'EHT160',
          'ifname': 'rai0',
          'bssid': '02:11:22:33:44:55',
        },
      ],
    }).single;
    expect(radio.widthMHz, 160);
    expect(radio.ifname, 'rai0');
    expect(radio.bssid, '02:11:22:33:44:55');
    final history = WifiHistory.fromJson({
      'interval': 60,
      'points': [
        [1720000000, 'MT7990_1_2', 1000, 500, 6.0, 16.0],
        [1720000060, 'MT7990_1_2', 2000, 800, null, null],
        [0, 'bad', 0, 0, 0, 0],
      ],
    });
    expect(history.points.length, 2);
    expect(history.points.first.txFailurePercent, 6);
    expect(history.points.last.rxCrcPercent, isNull);
  });

  test('system memory and SFP statuses preserve unavailable values', () {
    final memory = RouterMemory.fromSystemInfo({
      'memory': {'total': 1024, 'available': 256},
    });
    expect(memory?.usedPercent, 75);
    expect(RouterMemory.fromSystemInfo({'memory': {}}), isNull);
    expect(
      RouterMemory.fromSystemInfo({
        'memory': {'total': 1024},
      }),
      isNull,
    );

    final sfp = SfpPort.parseAll({
      'modules': [
        {
          'interface': 'sfp-wan',
          'module_slot': 'SFP-WAN',
          'link_up': true,
          'speed': '10000Mb/s',
          'supported': true,
        },
      ],
    });
    expect(sfp.single.speedMbps, 10000);
    expect(sfp.single.linkUp, isTrue);
    expect(SfpPort.parseAll({'modules': []}), isEmpty);
  });

  test('MT7988 SFP reports both real negotiated port speeds', () {
    final ports = SfpPort.parseAll({
      'modules': [
        {
          'supported': true,
          'link_up': true,
          'interface': 'eth1',
          'module_slot': 'SFP1',
          'speed': '2500Mb/s',
        },
        {
          'supported': true,
          'link_up': true,
          'interface': 'eth2',
          'module_slot': 'SFP2',
          'speed': '10000Mb/s',
        },
      ],
    });
    expect(ports.map((port) => port.speedMbps), [2500, 10000]);
    expect(ports.map((port) => port.slot), ['SFP1', 'SFP2']);
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
