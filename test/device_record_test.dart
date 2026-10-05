import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/models/device_record.dart';

void main() {
  test(
    'stale DHCP cannot merge freshly reported traffic after a read failure',
    () {
      final rows = DeviceRecord.fromSnapshot(
        RouterSnapshot(
          fetchedAt: DateTime.now(),
          devicesError: 'denied',
          dhcpDevices: const [
            DhcpDevice(
              ip: '192.168.2.112',
              name: 'old phone',
              mac: '02:11:22:33:44:55',
            ),
            DhcpDevice(
              ip: 'fd00::1',
              name: 'old phone',
              mac: '02:11:22:33:44:55',
            ),
          ],
          summary: TrafficSummary.fromJson({
            'clients': [
              {'ip': '192.168.2.112', 'bytes': 100},
              {'ip': 'fd00::1', 'bytes': 200},
            ],
          }),
        ),
      );
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.mac.isEmpty), isTrue);
    },
  );

  const mac = '02:11:22:33:44:55';
  const v6 = '240e:1234::1';
  test('MAC evidence merges dual stack and adds each IP traffic once', () {
    final rows = DeviceRecord.fromSnapshot(
      RouterSnapshot(
        fetchedAt: DateTime.now(),
        dhcpDevices: const [
          DhcpDevice(ip: '192.168.2.112', name: 'MZYtekiiPhone', mac: mac),
        ],
        hostHints: const [
          HostHint(mac: mac, name: '', addresses: ['192.168.2.112', v6]),
        ],
        summary: TrafficSummary.fromJson({
          'clients': [
            {'ip': '192.168.2.112', 'bytes': 100},
            {'ip': v6, 'bytes': 200},
            {'ip': '240e:1234:0:0:0:0:0:1', 'bytes': 200},
          ],
        }),
      ),
    );
    expect(rows, hasLength(1));
    expect(rows.single.addresses, hasLength(2));
    expect(rows.single.bytes, 300);
    expect(rows.single.name, 'MZYtekiiPhone');
  });
  test('same hostname or IPv6 prefix is never enough to merge', () {
    final rows = DeviceRecord.fromSnapshot(
      RouterSnapshot(
        fetchedAt: DateTime.now(),
        summary: TrafficSummary.fromJson({
          'clients': [
            {'ip': '240e:1234::1', 'name': 'phone', 'bytes': 20},
            {'ip': '240e:1234::2', 'name': 'phone', 'bytes': 30},
          ],
        }),
      ),
    );
    expect(rows, hasLength(2));
  });
  test('conflicting owners do not attribute IPv6 traffic to either device', () {
    final rows = DeviceRecord.fromSnapshot(
      RouterSnapshot(
        fetchedAt: DateTime.now(),
        dhcpDevices: const [
          DhcpDevice(ip: '192.168.2.1', name: 'one', mac: mac),
          DhcpDevice(ip: '192.168.2.2', name: 'two', mac: '02:11:22:33:44:66'),
        ],
        hostHints: const [
          HostHint(mac: mac, name: '', addresses: [v6]),
          HostHint(mac: '02:11:22:33:44:66', name: '', addresses: [v6]),
        ],
        summary: TrafficSummary.fromJson({
          'clients': [
            {'ip': v6, 'bytes': 50},
          ],
        }),
      ),
    );
    expect(rows, hasLength(3));
    expect(rows.where((r) => r.bytes == 50).single.mac, isEmpty);
  });
  test('DHCPv6 preserves explicit MAC and all assigned addresses', () {
    final leases = DhcpDevice.parseAll({
      'dhcp6_leases': [
        {
          'ip6addr': v6,
          'ip6addrs': [v6, 'fd00::1/128'],
          'macaddr': mac,
          'hostname': 'phone',
        },
        {'ip6addr': 'fd00::2', 'duid': '00030001021122334455'},
      ],
    });
    expect(leases.map((l) => l.ip), [v6, 'fd00::1', 'fd00::2']);
    expect(leases.last.mac, isEmpty);
  });
}
