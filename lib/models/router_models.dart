int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

class TrafficClient {
  const TrafficClient({
    required this.ip,
    required this.name,
    required this.bytes,
  });
  final String ip;
  final String name;
  final int bytes;

  factory TrafficClient.fromJson(Object? value) {
    final json = _map(value);
    final ip = '${json['ip'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    return TrafficClient(
      ip: ip,
      name: name.isEmpty ? ip : name,
      bytes: _number(json['bytes']),
    );
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
      collectedAt: epoch > 0
          ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
          : null,
      version: '${json['version'] ?? ''}',
      headlineDown: hasWanTotals
          ? _number(iface['down'])
          : _number(totals['down']),
      headlineUp: hasWanTotals ? _number(iface['up']) : _number(totals['up']),
      headlineSource: hasWanTotals ? '${iface['dev'] ?? 'WAN'}' : '已归属流量',
      hasWanTotals: hasWanTotals,
      attributedDown: _number(totals['down']),
      attributedUp: _number(totals['up']),
      clientCount: _number(totals['client_count']),
      clients: _list(
        json['clients'],
      ).map(TrafficClient.fromJson).where((c) => c.ip.isNotEmpty).toList(),
      apps: _list(
        json['apps'],
      ).map(TrafficApp.fromJson).where((a) => a.name.isNotEmpty).toList(),
    );
  }
}

class LiveRate {
  const LiveRate({
    required this.ready,
    required this.downBytesPerSecond,
    required this.upBytesPerSecond,
    required this.at,
  });
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
  const TrafficPoint({
    required this.at,
    required this.downBytesPerSecond,
    required this.upBytesPerSecond,
  });
  final DateTime at;
  final double downBytesPerSecond;
  final double upBytesPerSecond;
}

class TrafficSeries {
  const TrafficSeries({required this.interval, required this.points});
  final int interval;
  final List<TrafficPoint> points;

  /// Highest per-second rate in the series, across both directions; 0 when the
  /// series is empty. Used for the 峰值 figure on the traffic screen.
  double get peakBytesPerSecond => points.fold<double>(0, (max, point) {
    final pointMax = point.downBytesPerSecond > point.upBytesPerSecond
        ? point.downBytesPerSecond
        : point.upBytesPerSecond;
    return pointMax > max ? pointMax : max;
  });

  factory TrafficSeries.fromJson(Object? value) {
    final json = _map(value);
    final interval = _number(json['interval']);
    final safeInterval = interval > 0 ? interval : 1;
    final points = <TrafficPoint>[];
    for (final raw in _list(json['points'])) {
      if (raw is! List || raw.length < 3) continue;
      final epoch = _number(raw[0]);
      if (epoch <= 0) continue;
      points.add(
        TrafficPoint(
          at: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
          downBytesPerSecond: _number(raw[1]) / safeInterval,
          upBytesPerSecond: _number(raw[2]) / safeInterval,
        ),
      );
    }
    return TrafficSeries(interval: safeInterval, points: points);
  }
}

class WifiRadio {
  const WifiRadio({
    required this.name,
    required this.up,
    required this.ssids,
    required this.clientCount,
    this.band,
    this.channel,
  });
  final String name;
  final bool up;
  final List<String> ssids;
  final int? clientCount;

  /// Band as reported by the router (for example `5g`); null when the payload
  /// does not carry one, so the UI can say 未提供 instead of guessing.
  final String? band;

  /// Configured channel, or null when absent or set to `auto`.
  final int? channel;

  static List<WifiRadio> parseAll(Object? value) {
    final source = _map(value);
    if (source['radios'] is List) {
      return _list(source['radios'])
          .map((raw) {
            final radio = _map(raw);
            final channel = _number(radio['channel']);
            final ssid = '${radio['ssid'] ?? ''}';
            final band = '${radio['band'] ?? ''}';
            return WifiRadio(
              name: '${radio['name'] ?? ''}',
              up: radio['up'] == true,
              ssids: ssid.isEmpty ? const [] : [ssid],
              clientCount: null,
              band: band.isEmpty ? null : band,
              channel: channel > 0 ? channel : null,
            );
          })
          .where((radio) => radio.name.isNotEmpty)
          .toList();
    }
    return source.entries.where((entry) => entry.value is Map).map((entry) {
      final radio = _map(entry.value);
      final settings = _map(radio['config']);
      final ssids = <String>[];
      for (final raw in _list(radio['interfaces'])) {
        final ifaceConfig = _map(_map(raw)['config']);
        final ssid = '${ifaceConfig['ssid'] ?? ''}';
        if (ssid.isNotEmpty) ssids.add(ssid);
      }
      final band = '${settings['band'] ?? radio['band'] ?? ''}';
      final channel = _number(settings['channel'] ?? radio['channel']);
      return WifiRadio(
        name: entry.key,
        up: radio['up'] == true,
        ssids: ssids,
        clientCount: null,
        band: band.isEmpty ? null : band,
        channel: channel > 0 ? channel : null,
      );
    }).toList();
  }
}

class RouterMemory {
  const RouterMemory({required this.totalBytes, required this.availableBytes});
  final int totalBytes;
  final int availableBytes;

  double get usedPercent =>
      (totalBytes - availableBytes).clamp(0, totalBytes) * 100 / totalBytes;

  static RouterMemory? fromSystemInfo(Object? value) {
    final memory = _map(_map(value)['memory']);
    if (!memory.containsKey('total') || !memory.containsKey('available')) {
      return null;
    }
    final total = _number(memory['total']);
    final available = _number(memory['available']);
    if (total <= 0 || available < 0 || available > total) return null;
    return RouterMemory(totalBytes: total, availableBytes: available);
  }
}

class CpuCounters {
  const CpuCounters({required this.total, required this.idle});
  final int total;
  final int idle;

  static CpuCounters? fromJson(Object? value) {
    final json = _map(value);
    final total = _number(json['total']);
    final idle = _number(json['idle']);
    if (total <= 0 || idle < 0 || idle > total) return null;
    return CpuCounters(total: total, idle: idle);
  }

  double? usageSince(CpuCounters? previous) {
    if (previous == null) return null;
    final elapsed = total - previous.total;
    final idleElapsed = idle - previous.idle;
    if (elapsed <= 0 || idleElapsed < 0 || idleElapsed > elapsed) return null;
    return (elapsed - idleElapsed) * 100 / elapsed;
  }
}

class SfpPort {
  const SfpPort({
    required this.interface,
    required this.slot,
    required this.linkUp,
    required this.speedMbps,
  });
  final String interface;
  final String slot;
  final bool? linkUp;
  final int? speedMbps;

  static List<SfpPort> parseAll(Object? value) => _list(_map(value)['modules'])
      .map((raw) {
        final json = _map(raw);
        final speed = RegExp(
          r'^(\d+)\s*Mb/s$',
          caseSensitive: false,
        ).firstMatch('${json['speed'] ?? ''}');
        return SfpPort(
          interface: '${json['interface'] ?? ''}',
          slot: '${json['module_slot'] ?? ''}',
          linkUp: json['link_up'] is bool ? json['link_up'] as bool : null,
          speedMbps: speed == null ? null : int.tryParse(speed.group(1)!),
        );
      })
      .where((port) => port.interface.isNotEmpty)
      .toList();
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
    this.memory,
    this.cpuCounters,
    this.cpuUsagePercent,
    this.sfpPorts = const [],
    this.trafficError,
    this.liveError,
    this.seriesError,
    this.devicesError,
    this.systemError,
    this.wifiError,
    this.metricsError,
    this.sfpError,
  });
  final DateTime fetchedAt;
  final TrafficSummary? summary;
  final LiveRate? live;
  final TrafficSeries? series;
  final List<WifiRadio> radios;
  final List<DhcpDevice> dhcpDevices;
  final int? uptimeSeconds;
  final RouterMemory? memory;
  final CpuCounters? cpuCounters;
  final double? cpuUsagePercent;
  final List<SfpPort> sfpPorts;
  final String? trafficError;
  final String? liveError;
  final String? seriesError;
  final String? devicesError;
  final String? systemError;
  final String? wifiError;
  final String? metricsError;
  final String? sfpError;
}

String formatBytes(num value) {
  var amount = value.toDouble();
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var index = 0;
  while (amount >= 1024 && index < units.length - 1) {
    amount /= 1024;
    index++;
  }
  return '${amount.toStringAsFixed(index == 0
      ? 0
      : amount >= 100
      ? 0
      : 1)} ${units[index]}';
}

String formatRate(num bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';
