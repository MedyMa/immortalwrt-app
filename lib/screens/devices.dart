part of '../main.dart';

// ---------------------------------------------------------------------------
// 设备
// ---------------------------------------------------------------------------

/// One row in the device list: a DHCP lease, a traffic record, or both.
class _DeviceRow {
  const _DeviceRow({
    required this.name,
    required this.ip,
    required this.mac,
    required this.bytes,
    required this.hasLease,
    required this.hasTraffic,
  });

  final String name;
  final String ip;
  final String mac;
  final int? bytes;
  final bool hasLease;
  final bool hasTraffic;
}

/// Devices merged by IP.
class _DeviceIndex {
  const _DeviceIndex({required this.rows});

  final List<_DeviceRow> rows;

  factory _DeviceIndex.of(RouterSnapshot snapshot) {
    final clients = <String, TrafficClient>{
      for (final client in snapshot.summary?.clients ?? const <TrafficClient>[])
        client.ip: client,
    };
    final rows = <_DeviceRow>[];
    for (final lease in snapshot.dhcpDevices) {
      final client = clients.remove(lease.ip);
      rows.add(
        _DeviceRow(
          name: lease.name,
          ip: lease.ip,
          mac: lease.mac,
          bytes: client?.bytes,
          hasLease: true,
          hasTraffic: client != null,
        ),
      );
    }
    for (final client in clients.values) {
      rows.add(
        _DeviceRow(
          name: client.name,
          ip: client.ip,
          mac: '',
          bytes: client.bytes,
          hasLease: false,
          hasTraffic: true,
        ),
      );
    }
    return _DeviceIndex(rows: rows);
  }
}

class _Devices extends StatelessWidget {
  const _Devices({required this.snapshot});

  final RouterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final index = _DeviceIndex.of(snapshot);
    final rows = index.rows;
    final leaseCount = snapshot.dhcpDevices.length;
    final trafficCount = snapshot.summary?.clients.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('设备记录', style: _titleStyle(context))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${index.rows.length}',
                    style: _figureStyle(context, size: 34),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '台',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mutedOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'DHCP $leaseCount · 流量记录 $trafficCount',
                style: _bodyStyle(context),
              ),
              const SizedBox(height: 4),
              Text('设备记录不代表当前在线', style: _bodyStyle(context)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _Card(child: Text('暂无 DHCP 租约或设备流量数据。', style: _bodyStyle(context)))
        else
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const _Hairline(),
                  _DeviceTile(row: rows[i]),
                ],
              ],
            ),
          ),
        if (snapshot.devicesError != null) ...[
          const SizedBox(height: 10),
          _Notice(
            'DHCP 租约暂不可用：${snapshot.devicesError}',
            Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.row});

  final _DeviceRow row;

  @override
  Widget build(BuildContext context) {
    final color = row.hasTraffic ? _violet : _blue;
    // One source tag per row, as the mockup does. Listing both tags overflowed
    // the line and the ellipsis ate the second one ("… · DHCP 租约 · 有…"), and
    // nothing is lost by dropping it: the trailing column already shows the
    // session total, or "—" when the device has no traffic at all.
    final tags = <String>[
      row.ip,
      if (row.hasLease) 'DHCP 租约' else if (row.hasTraffic) '有流量记录',
    ];
    final bytes = row.bytes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _Avatar(label: _initials(row.name), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name.isEmpty ? row.ip : row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _inkOf(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tags.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _mutedOf(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bytes == null ? '—' : formatBytes(bytes),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _inkOf(context),
                ),
              ),
              if (bytes != null)
                Text(
                  '本次会话',
                  style: TextStyle(fontSize: 11, color: _mutedOf(context)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
