import 'dart:io';
import 'router_models.dart';

String? _addressKey(String value) {
  final plain = value.split('/').first;
  final parsed = InternetAddress.tryParse(plain.split('%').first);
  if (parsed == null) return null;
  final zone = plain.contains('%') ? '%${plain.split('%').last}' : '';
  return '${parsed.type.name}:${parsed.rawAddress.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}$zone';
}

String? _macKey(String value) {
  final mac = value.toLowerCase().replaceAll('-', ':');
  if (!RegExp(r'^(?:[0-9a-f]{2}:){5}[0-9a-f]{2}$').hasMatch(mac) ||
      mac == '00:00:00:00:00:00' ||
      (int.parse(mac.substring(0, 2), radix: 16) & 1) != 0) {
    return null;
  }
  return mac;
}

class DeviceRecord {
  const DeviceRecord({
    required this.name,
    required this.addresses,
    required this.mac,
    required this.bytes,
    required this.hasLease,
    required this.hasTraffic,
    required this.hasHint,
  });
  final String name;
  final List<String> addresses;
  final String mac;
  final int? bytes;
  final bool hasLease, hasTraffic, hasHint;
  String get ip => ipv4.isNotEmpty ? ipv4.first : addresses.first;
  List<String> get ipv4 => addresses.where((a) => !a.contains(':')).toList();
  List<String> get ipv6 => addresses.where((a) => a.contains(':')).toList();

  static List<DeviceRecord> fromSnapshot(RouterSnapshot snapshot) {
    final leases = snapshot.devicesError == null
        ? snapshot.dhcpDevices
        : <DhcpDevice>[];
    final owners = <String, Set<String>>{};
    void own(String ip, String mac) {
      final address = _addressKey(ip), owner = _macKey(mac);
      if (address != null && owner != null) (owners[address] ??= {}).add(owner);
    }

    for (final lease in leases) {
      own(lease.ip, lease.mac);
    }
    for (final hint in snapshot.hostHints) {
      for (final ip in hint.addresses) {
        own(ip, hint.mac);
      }
    }
    final records = <String, _RecordBuilder>{};
    _RecordBuilder record(String ip, [String? explicitMac]) {
      final key = _addressKey(ip)!;
      final evidence = owners[key];
      final mac =
          _macKey(explicitMac ?? '') ??
          (evidence?.length == 1 ? evidence!.single : null);
      return records.putIfAbsent(
        mac == null ? 'ip:$key' : 'mac:$mac',
        () => _RecordBuilder(mac ?? ''),
      );
    }

    for (final lease in leases) {
      if (_addressKey(lease.ip) == null) continue;
      final builder = record(lease.ip, lease.mac);
      builder.add(lease.ip);
      builder.setName(lease.name);
      builder.hasLease = true;
    }
    // Duplicate textual forms of one address are one counter, not extra traffic.
    final clients = <String, TrafficClient>{};
    for (final client in snapshot.summary?.clients ?? <TrafficClient>[]) {
      final key = _addressKey(client.ip);
      if (key == null) continue;
      final old = clients[key];
      if (old == null || client.bytes > old.bytes) clients[key] = client;
    }
    for (final client in clients.values) {
      final builder = record(client.ip);
      builder.add(client.ip);
      builder.setName(client.name);
      builder.bytes = (builder.bytes ?? 0) + client.bytes;
      builder.hasTraffic = true;
    }
    // Hints enrich devices with activity/leases; do not add every idle neighbour.
    for (final hint in snapshot.hostHints) {
      final mac = _macKey(hint.mac);
      final builder = mac == null ? null : records['mac:$mac'];
      if (builder == null) continue;
      builder.setName(hint.name);
      for (final ip in hint.addresses) {
        final key = _addressKey(ip);
        if (key != null && owners[key]?.length == 1) {
          builder.add(ip);
          builder.hasHint = true;
        }
      }
    }
    return records.values.map((b) => b.build()).toList();
  }
}

class _RecordBuilder {
  _RecordBuilder(this.mac);
  final String mac;
  final Map<String, String> addresses = {};
  String name = '';
  int? bytes;
  bool hasLease = false, hasTraffic = false, hasHint = false;
  void add(String ip) {
    addresses.putIfAbsent(_addressKey(ip)!, () => ip.split('/').first);
  }

  void setName(String value) {
    if (name.isEmpty &&
        value.isNotEmpty &&
        value != '*' &&
        _addressKey(value) == null) {
      name = value;
    }
  }

  DeviceRecord build() => DeviceRecord(
    name: name,
    addresses: List.unmodifiable(addresses.values),
    mac: mac,
    bytes: bytes,
    hasLease: hasLease,
    hasTraffic: hasTraffic,
    hasHint: hasHint,
  );
}
