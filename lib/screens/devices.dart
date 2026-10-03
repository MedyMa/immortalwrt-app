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
    final identity = DeviceIdentity.fromName(row.name);
    final bytes = row.bytes;
    return InkWell(
      key: ValueKey('device-${row.ip}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDeviceDetails(context, row, identity),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _DeviceIcon(identity: identity, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name.isEmpty || row.name == row.ip || row.name == '*'
                        ? '未命名设备'
                        : '${row.name}${identity.model == null ? '' : ' · ${identity.model}'}',
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
                    '${identity.typeLabel} · ${row.ip}',
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
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.identity, required this.color});
  final DeviceIdentity identity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (symbol, fallback) = switch (identity.kind) {
      DeviceKind.phone => ('iphone', Icons.smartphone_rounded),
      DeviceKind.tablet => ('ipad', Icons.tablet_mac_rounded),
      DeviceKind.laptop => ('laptopcomputer', Icons.laptop_mac_rounded),
      DeviceKind.desktop => ('desktopcomputer', Icons.desktop_windows_rounded),
      DeviceKind.tv => ('tv', Icons.tv_rounded),
      DeviceKind.nas => ('externaldrive', Icons.storage_rounded),
      DeviceKind.console => ('gamecontroller', Icons.sports_esports_rounded),
      DeviceKind.printer => ('printer', Icons.print_rounded),
      DeviceKind.camera => ('camera', Icons.videocam_rounded),
      DeviceKind.router => ('wifi.router', Icons.router_rounded),
      DeviceKind.unknown => ('square.stack.3d.up', Icons.devices_other_rounded),
    };
    final generic = _AppleSymbol(
      symbol,
      fallback: fallback,
      size: 23,
      color: color,
    );
    final slug = identity.slug;
    return Semantics(
      label: identity.label,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: _isDark(context) ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: slug == null
            ? generic
            : SvgPicture.asset(
                'assets/device-brands/$slug.svg',
                key: ValueKey('device-brand-$slug'),
                width: 25,
                height: 25,
                colorFilter: ColorFilter.mode(_inkOf(context), BlendMode.srcIn),
                excludeFromSemantics: true,
                placeholderBuilder: (_) => generic,
                errorBuilder: (_, _, _) => generic,
              ),
      ),
    );
  }
}

void _showDeviceDetails(
  BuildContext context,
  _DeviceRow row,
  DeviceIdentity identity,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GlassSurface(
      radius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('设备详情', style: _titleStyle(context)),
              const SizedBox(height: 18),
              for (final entry in <(String, String)>[
                (
                  '名称',
                  row.name.isEmpty || row.name == row.ip || row.name == '*'
                      ? '未命名设备'
                      : row.name,
                ),
                ('类型', identity.typeLabel),
                if (identity.brand != null) ('品牌', identity.brand!),
                if (identity.model != null) ('型号', identity.model!),
                ('IP', row.ip),
                ('MAC', row.mac.isEmpty ? '未提供' : row.mac),
                (
                  '记录来源',
                  [
                    if (row.hasLease) 'DHCP 租约',
                    if (row.hasTraffic) '流量记录',
                  ].join(' · '),
                ),
                (
                  '流量',
                  row.bytes == null
                      ? '未提供'
                      : '${formatBytes(row.bytes!)} · 本次会话',
                ),
                ('识别依据', identity.evidence),
              ]) ...[
                Text(entry.$1, style: _bodyStyle(context)),
                const SizedBox(height: 3),
                SelectableText(
                  entry.$2,
                  style: TextStyle(fontSize: 15, color: _inkOf(context)),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
