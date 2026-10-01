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

/// Devices merged by IP, plus how many DHCP leases also had a traffic record.
class _DeviceIndex {
  const _DeviceIndex({required this.rows, required this.merged});

  final List<_DeviceRow> rows;
  final int merged;

  List<_DeviceRow> get withTraffic =>
      rows.where((row) => row.hasTraffic).toList(growable: false);

  factory _DeviceIndex.of(RouterSnapshot snapshot) {
    final clients = <String, TrafficClient>{
      for (final client in snapshot.summary?.clients ?? const <TrafficClient>[])
        client.ip: client,
    };
    final rows = <_DeviceRow>[];
    var merged = 0;
    for (final lease in snapshot.dhcpDevices) {
      final client = clients.remove(lease.ip);
      if (client != null) merged++;
      rows.add(_DeviceRow(
        name: lease.name,
        ip: lease.ip,
        mac: lease.mac,
        bytes: client?.bytes,
        hasLease: true,
        hasTraffic: client != null,
      ));
    }
    for (final client in clients.values) {
      rows.add(_DeviceRow(
        name: client.name,
        ip: client.ip,
        mac: '',
        bytes: client.bytes,
        hasLease: false,
        hasTraffic: true,
      ));
    }
    return _DeviceIndex(rows: rows, merged: merged);
  }
}

class _Devices extends StatefulWidget {
  const _Devices({required this.snapshot});

  final RouterSnapshot snapshot;

  @override
  State<_Devices> createState() => _DevicesState();
}

class _DevicesState extends State<_Devices> {
  static const _filters = ['全部设备', '有流量记录'];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final index = _DeviceIndex.of(widget.snapshot);
    final rows = _filter == 0 ? index.rows : index.withTraffic;
    final leaseCount = widget.snapshot.dhcpDevices.length;
    final trafficCount = widget.snapshot.summary?.clients.length ?? 0;
    final mergeNote =
        index.merged > 0 ? ' · 已合并 ${index.merged} 个重复 IP' : ' · 无重复 IP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Lead('DHCP 租约与 Traffic App 流量记录；租约不表示设备此刻在线。'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('已发现设备', style: _titleStyle(context))),
                  Text('不代表此刻在线',
                      style:
                          TextStyle(fontSize: 11.5, color: _mutedOf(context))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${index.rows.length}',
                      style: _figureStyle(context, size: 34)),
                  const SizedBox(width: 6),
                  Text('台',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _mutedOf(context))),
                ],
              ),
              const SizedBox(height: 8),
              Text('DHCP $leaseCount · 流量记录 $trafficCount$mergeNote',
                  style: _bodyStyle(context)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Segmented(
            options: _filters,
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value)),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _Card(
            child: Text(_filter == 0 ? '暂无 DHCP 租约或设备流量数据。' : '暂无有流量记录的设备。',
                style: _bodyStyle(context)),
          )
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
        if (widget.snapshot.devicesError != null) ...[
          const SizedBox(height: 10),
          _Notice('DHCP 租约暂不可用：${widget.snapshot.devicesError}',
              Icons.info_outline_rounded),
        ],
        const SizedBox(height: 10),
        const _SectionHeader(title: '关于在线状态'),
        _Card(
          child: Text(
              '本页合并 DHCP 租约与 Traffic App 流量记录，两者都只能说明设备曾经出现过，不能证明它此刻在线。',
              style: _bodyStyle(context)),
        ),
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
                Text(row.name.isEmpty ? row.ip : row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _inkOf(context))),
                const SizedBox(height: 3),
                Text(tags.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: _mutedOf(context))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(bytes == null ? '—' : formatBytes(bytes),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _inkOf(context))),
              if (bytes != null)
                Text('本次会话',
                    style: TextStyle(fontSize: 11, color: _mutedOf(context))),
            ],
          ),
        ],
      ),
    );
  }
}
