int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

class TrafficClient {
  const TrafficClient(
      {required this.ip, required this.name, required this.bytes});
  final String ip;
  final String name;
  final int bytes;

  factory TrafficClient.fromJson(Object? value) {
    final json = _map(value);
    final ip = '${json['ip'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    return TrafficClient(
        ip: ip, name: name.isEmpty ? ip : name, bytes: _number(json['bytes']));
  }
}

class DhcpDevice {
  const DhcpDevice({required this.ip, required this.name, required this.mac});
  final String ip;
  final String name;
  final String mac;

  static List<DhcpDevice> parseAll(Object? value) =>
      _list(_map(value)['dhcp_leases'])
          .map((raw) {
            final item = _map(raw);
            final ip = '${item['ipaddr'] ?? ''}';
            final hostname = '${item['hostname'] ?? ''}';
            return DhcpDevice(
              ip: ip,
              name: hostname.isEmpty || hostname == '*' ? ip : hostname,
              mac: '${item['macaddr'] ?? ''}',
            );
          })
          .where((device) => device.ip.isNotEmpty)
          .toList();
}

class TrafficApp {
  const TrafficApp({required this.name, required this.down, required this.up});
  final String name;
  final int down;
  final int up;
  int get bytes => down + up;

  factory TrafficApp.fromJson(Object? value) {
    final json = _map(value);
    return TrafficApp(
      name: '${json['name'] ?? ''}',
      down: _number(json['down']),
      up: _number(json['up']),
    );
  }
}

class TrafficSummary {
  const TrafficSummary({
    required this.collectedAt,
    required this.version,
    required this.headlineDown,
    required this.headlineUp,
    required this.headlineSource,
    required this.hasWanTotals,
    required this.attributedDown,
    required this.attributedUp,
    required this.clientCount,
    required this.clients,
    required this.apps,
  });

  final DateTime? collectedAt;
  final String version;
  final int headlineDown;
  final int headlineUp;
  final String headlineSource;
  final bool hasWanTotals;
  final int attributedDown;
  final int attributedUp;
  final int clientCount;
  final List<TrafficClient> clients;
  final List<TrafficApp> apps;

  factory TrafficSummary.fromJson(Object? value) {
    final json = _map(value);
    final totals = _map(json['totals']);
    final iface = _map(json['iface']);
    final hasWanTotals = iface.containsKey('down') && iface.containsKey('up');
    final epoch = _number(json['collected_at']);
    return TrafficSummary(
      collectedAt:
          epoch > 0 ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000) : null,
      version: '${json['version'] ?? ''}',
      headlineDown:
          hasWanTotals ? _number(iface['down']) : _number(totals['down']),
      headlineUp: hasWanTotals ? _number(iface['up']) : _number(totals['up']),
      headlineSource: hasWanTotals ? '${iface['dev'] ?? 'WAN'}' : '已归属流量',
      hasWanTotals: hasWanTotals,
      attributedDown: _number(totals['down']),
      attributedUp: _number(totals['up']),
      clientCount: _number(totals['client_count']),
      clients: _list(json['clients'])
          .map(TrafficClient.fromJson)
          .where((c) => c.ip.isNotEmpty)
          .toList(),
      apps: _list(json['apps'])
          .map(TrafficApp.fromJson)
          .where((a) => a.name.isNotEmpty)
          .toList(),
    );
  }
}

class LiveRate {
  const LiveRate(
      {required this.ready,
      required this.downBytesPerSecond,
      required this.upBytesPerSecond,
      required this.at});
  final bool ready;
  final int downBytesPerSecond;
  final int upBytesPerSecond;
  final DateTime? at;

  factory LiveRate.fromJson(Object? value) {
    final json = _map(value);
    final epoch = _number(json['at']);
    return LiveRate(
      ready: json['ready'] == true || json['ready'] == 1,
      downBytesPerSecond: _number(json['bps_down']),
      upBytesPerSecond: _number(json['bps_up']),
      at: epoch > 0 ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000) : null,
    );
  }
}

class TrafficPoint {
  const TrafficPoint(
      {required this.at,
      required this.downBytesPerSecond,
      required this.upBytesPerSecond});
  final DateTime at;
  final double downBytesPerSecond;
  final double upBytesPerSecond;
}

class TrafficSeries {
  const TrafficSeries({required this.interval, required this.points});
  final int interval;
  final List<TrafficPoint> points;

  factory TrafficSeries.fromJson(Object? value) {
    final json = _map(value);
    final interval = _number(json['interval']);
    final safeInterval = interval > 0 ? interval : 1;
    final points = <TrafficPoint>[];
    for (final raw in _list(json['points'])) {
      if (raw is! List || raw.length < 3) continue;
      final epoch = _number(raw[0]);
      if (epoch <= 0) continue;
      points.add(TrafficPoint(
        at: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
        downBytesPerSecond: _number(raw[1]) / safeInterval,
        upBytesPerSecond: _number(raw[2]) / safeInterval,
      ));
    }
    return TrafficSeries(interval: safeInterval, points: points);
  }
}

class WifiRadio {
  const WifiRadio(
      {required this.name,
      required this.up,
      required this.ssids,
      required this.clientCount});
  final String name;
  final bool up;
  final List<String> ssids;
  final int? clientCount;

  static List<WifiRadio> parseAll(Object? value) {
    final source = _map(value);
    return source.entries.where((entry) => entry.value is Map).map((entry) {
      final radio = _map(entry.value);
      final ssids = <String>[];
      for (final raw in _list(radio['interfaces'])) {
        final config = _map(_map(raw)['config']);
        final ssid = '${config['ssid'] ?? ''}';
        if (ssid.isNotEmpty) ssids.add(ssid);
      }
      return WifiRadio(
        name: entry.key,
        up: radio['up'] == true,
        ssids: ssids,
        clientCount: null,
      );
    }).toList();
  }
}

class RouterSnapshot {
  const RouterSnapshot({
    required this.fetchedAt,
    this.summary,
    this.live,
    this.series,
    this.radios = const [],
    this.dhcpDevices = const [],
    this.uptimeSeconds,
    this.trafficError,
    this.wifiError,
  });
  final DateTime fetchedAt;
  final TrafficSummary? summary;
  final LiveRate? live;
  final TrafficSeries? series;
  final List<WifiRadio> radios;
  final List<DhcpDevice> dhcpDevices;
  final int? uptimeSeconds;
  final String? trafficError;
  final String? wifiError;
}

String formatBytes(num value) {
  var amount = value.toDouble();
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var index = 0;
  while (amount >= 1024 && index < units.length - 1) {
    amount /= 1024;
    index++;
  }
  return '${amount.toStringAsFixed(index == 0 ? 0 : amount >= 100 ? 0 : 1)} ${units[index]}';
}

String formatRate(num bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';
