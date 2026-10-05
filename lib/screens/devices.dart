part of '../main.dart';

// ---------------------------------------------------------------------------
// 设备
// ---------------------------------------------------------------------------

typedef _DeviceRow = DeviceRecord;

class _DeviceIndex {
  const _DeviceIndex({required this.rows});
  final List<DeviceRecord> rows;
  factory _DeviceIndex.of(RouterSnapshot snapshot) =>
      _DeviceIndex(rows: DeviceRecord.fromSnapshot(snapshot));
}

class _Devices extends StatelessWidget {
  const _Devices({required this.snapshot});

  final RouterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final index = _DeviceIndex.of(snapshot);
    final rows = index.rows;
    final leaseCount = rows.where((row) => row.hasLease).length;
    final trafficCount = rows.where((row) => row.hasTraffic).length;

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
        if (snapshot.hostHintsError != null) ...[
          const SizedBox(height: 10),
          _Notice('地址归属信息暂不可用，未确认的地址单独显示。', Icons.info_outline_rounded),
        ],
        if (snapshot.localAddressesError != null) ...[
          const SizedBox(height: 10),
          _Notice('路由器自身地址暂不可用，设备记录可能包含路由器流量。', Icons.info_outline_rounded),
        ],
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
                  for (final address in [
                    if (row.ipv4.isNotEmpty)
                      '${identity.typeLabel} · IPv4 ${row.ipv4.first}',
                    if (row.ipv6.isNotEmpty) 'IPv6 ${row.ipv6.first}',
                  ])
                    Text(
                      address,
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
      DeviceKind.watch => ('applewatch', Icons.watch_rounded),
      DeviceKind.speaker => ('hifispeaker', Icons.speaker_rounded),
      DeviceKind.light => ('lightbulb', Icons.lightbulb_outline_rounded),
      DeviceKind.plug => ('powerplug', Icons.power_rounded),
      DeviceKind.sensor => ('sensor', Icons.sensors_rounded),
      DeviceKind.vacuum => ('circle.dotted', Icons.cleaning_services_rounded),
      DeviceKind.appliance => ('washer', Icons.kitchen_rounded),
      DeviceKind.iot => ('house', Icons.home_work_outlined),
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
    sheetAnimationStyle: _sheetAnimationStyle(context),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).platform == TargetPlatform.iOS
        ? Colors.transparent
        : null,
    builder: (context) => _DeviceDetailSheet(row: row, identity: identity),
  );
}
