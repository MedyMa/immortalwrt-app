part of '../main.dart';

// ---------------------------------------------------------------------------
// 总览
// ---------------------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview({
    required this.snapshot,
    required this.endpoint,
    required this.onOpen,
    this.liveSnapshot,
    this.error,
  });

  final RouterSnapshot snapshot;
  final String endpoint;
  final ValueChanged<int> onOpen;
  final String? error;
  final ValueListenable<RouterSnapshot?>? liveSnapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final offline = error != null;

    final down = summary?.headlineDown;
    final up = summary?.headlineUp;
    final total = down == null || up == null ? null : down + up;
    final source = summary?.headlineSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: liveSnapshot == null
              ? _OverviewConnection(
                  snapshot: snapshot,
                  endpoint: endpoint,
                  error: error,
                  onOpen: onOpen,
                )
              : ValueListenableBuilder<RouterSnapshot?>(
                  valueListenable: liveSnapshot!,
                  builder: (context, value, _) => _OverviewConnection(
                    snapshot: value ?? snapshot,
                    endpoint: endpoint,
                    error: error,
                    onOpen: onOpen,
                  ),
                ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '流量概览', trail: '本次采集会话'),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: summary == null
                    ? '下载'
                    : summary.hasWanTotals
                    ? 'WAN 下载'
                    : '归属下载',
                icon: Icons.south_rounded,
                color: _blue,
                value: down == null ? '—' : formatBytes(down),
                caption: down == null ? '未获取到数据' : source,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: summary == null
                    ? '上传'
                    : summary.hasWanTotals
                    ? 'WAN 上传'
                    : '归属上传',
                icon: Icons.north_rounded,
                color: _violet,
                value: up == null ? '—' : formatBytes(up),
                caption: up == null ? '未获取到数据' : source,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          padding: const EdgeInsets.all(14),
          child: Text(
            total == null
                ? '暂未获取到 Traffic App 采集数据'
                : '合计 ${formatBytes(total)} · 来源 ${source ?? '未提供'}',
            style: _bodyStyle(context),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '硬件加速'),
        _PpeCard(snapshot: snapshot, offline: offline),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'MT7988 状态'),
        _Card(
          child: Column(
            children: [
              _TemperatureStrip(
                readings: snapshot.temperatures,
                unavailable: offline || snapshot.metricsError != null,
              ),
              const SizedBox(height: 18),
              const _Hairline(),
              _InfoRow(
                icon: Icons.memory_rounded,
                label: 'CPU 使用率',
                value: snapshot.cpuUsagePercent == null
                    ? (snapshot.metricsError == null ? '采样中' : '未获取')
                    : '${snapshot.cpuUsagePercent!.toStringAsFixed(0)}%',
              ),
              const _Hairline(),
              _InfoRow(
                icon: Icons.storage_rounded,
                label: '内存使用率',
                value: snapshot.memory == null
                    ? '未获取'
                    : '${snapshot.memory!.usedPercent.toStringAsFixed(0)}%',
              ),
              const _Hairline(),
              for (final port in snapshot.sfpPorts) ...[
                _InfoRow(
                  icon: Icons.settings_ethernet_rounded,
                  label: port.slot.isEmpty ? port.interface : port.slot,
                  value: _sfpStatus(
                    port,
                    showTemperature: !offline && snapshot.sfpError == null,
                  ),
                ),
                const _Hairline(),
              ],
              if (snapshot.sfpPorts.isEmpty) ...[
                _InfoRow(
                  icon: Icons.settings_ethernet_rounded,
                  label: 'SFP 连接',
                  value: '未获取',
                ),
                const _Hairline(),
              ],
              _InfoRow(
                icon: Icons.devices_rounded,
                label: '有流量记录的设备',
                value: summary == null
                    ? '—'
                    : '${_DeviceIndex.of(snapshot).rows.where((row) => row.hasTraffic).length}',
                onTap: () => onOpen(1),
              ),
              const _Hairline(),
              _InfoRow(
                icon: Icons.wifi_rounded,
                label: 'BE14 无线状态',
                value: snapshot.wifiError != null
                    ? '不可用'
                    : '${snapshot.radios.where((radio) => radio.up).length} 个射频已启用',
                onTap: () => onOpen(2),
              ),
              const _Hairline(),
              _InfoRow(
                icon: Icons.memory_rounded,
                label: '系统运行时间',
                value: _uptime(snapshot.uptimeSeconds),
              ),
            ],
          ),
        ),
        if (snapshot.trafficError != null) ...[
          const SizedBox(height: 12),
          const _Notice(
            'Traffic App 当前不可用，请确认已安装并授权读取',
            Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }
}

/// Only this area rebuilds for the one-second live poll. Hardware and chrome
/// keep their last full-refresh widgets; error/recovery still rebuilds the page.
class _OverviewConnection extends StatelessWidget {
  const _OverviewConnection({
    required this.snapshot,
    required this.endpoint,
    required this.onOpen,
    this.error,
  });
  final RouterSnapshot snapshot;
  final String endpoint;
  final ValueChanged<int> onOpen;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final collected = snapshot.summary?.collectedAt;
    final stale =
        collected != null &&
        snapshot.fetchedAt.difference(collected) > const Duration(seconds: 60);
    final offline = error != null;
    final missing = snapshot.summary == null && snapshot.live == null;
    final remote = endpoint.startsWith('https://');
    final clock =
        '${snapshot.fetchedAt.hour.toString().padLeft(2, '0')}:${snapshot.fetchedAt.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Lead('家中网络 · ${remote ? '远程' : '本地'}连接 · $clock 更新'),
        _Hero(
          identity: remote ? 'MT7988 · 远程连接' : 'MT7988 · 本地连接',
          stateLabel: offline
              ? '连接中断'
              : stale
              ? '数据延迟'
              : '已连接',
          stateColor: offline
              ? _red
              : stale
              ? _amber
              : _green,
          headline: offline
              ? '连接已中断'
              : stale
              ? '数据更新延迟'
              : missing
              ? '路由器已连接'
              : '',
          detail: offline
              ? '显示上次成功读取的数据'
              : stale
              ? 'Traffic 采集已超过 60 秒未更新'
              : missing
              ? '未获取到 Traffic 采集数据'
              : '',
          showTopology: !offline && !stale && !missing,
          onOpenDevices: () => onOpen(1),
          live: snapshot.live,
        ),
      ],
    );
  }
}

class _TemperatureStrip extends StatelessWidget {
  const _TemperatureStrip({required this.readings, required this.unavailable});
  final List<RouterTemperature> readings;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final entry in const [
        ('cpu', 'CPU', 'MT7988'),
        ('wifi', 'Wi-Fi', 'BE14'),
        ('disk', '硬盘', ''),
      ])
        Expanded(child: _figure(context, entry.$1, entry.$2, entry.$3)),
    ],
  );

  Widget _figure(
    BuildContext context,
    String kind,
    String label,
    String caption,
  ) {
    final now = DateTime.now();
    final matches =
        readings.where((r) => r.kind == kind && r.isFresh(now)).toList()
          ..sort((a, b) => b.celsius.compareTo(a.celsius));
    final reading = unavailable || matches.isEmpty ? null : matches.first;
    final source = caption.isNotEmpty
        ? caption
        : reading == null
        ? '—'
        : reading.name == 'nvme'
        ? 'NVMe'
        : '存储';
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _mutedOf(context))),
        const SizedBox(height: 7),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: reading == null
                    ? '—'
                    : reading.celsius.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _inkOf(context),
                ),
              ),
              if (reading != null)
                TextSpan(
                  text: '°C',
                  style: TextStyle(fontSize: 12, color: _mutedOf(context)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(source, style: TextStyle(fontSize: 11, color: _mutedOf(context))),
      ],
    );
  }
}

String _ppePercentLabel(double percent) {
  return '${percent.toStringAsFixed(4)}%';
}

class _PpeCard extends StatelessWidget {
  const _PpeCard({required this.snapshot, required this.offline});
  final RouterSnapshot snapshot;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final unavailable = snapshot.ppeError != null || snapshot.ppeTables.isEmpty;
    final percentageStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: offline || unavailable ? _mutedOf(context) : _blue,
    );
    // Reserve only the widest current percentage, so small values stay compact.
    var percentageWidth = 0.0;
    for (final table in snapshot.ppeTables) {
      final painter = TextPainter(
        text: TextSpan(
          text: table.usedPercent == null
              ? '—'
              : _ppePercentLabel(table.usedPercent!),
          style: DefaultTextStyle.of(context).style.merge(percentageStyle),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      percentageWidth = math.max(percentageWidth, painter.width.ceilToDouble());
      painter.dispose();
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'HNAT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _inkOf(context),
                  ),
                ),
              ),
              _Pill(
                offline
                    ? '连接中断'
                    : unavailable
                    ? '未获取'
                    : '已启用',
                offline
                    ? _red
                    : unavailable
                    ? _mutedOf(context)
                    : _green,
              ),
            ],
          ),
          if (snapshot.ppeTables.isEmpty) ...[
            const SizedBox(height: 18),
            Text('暂无 PPE 数据', style: _bodyStyle(context)),
          ],
          for (final table in snapshot.ppeTables) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PPE ${table.index}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _inkOf(context),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${table.bound ?? '—'} / ${table.capacity ?? '—'}',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _mutedOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: percentageWidth,
                  child: Text(
                    table.usedPercent == null
                        ? '—'
                        : _ppePercentLabel(table.usedPercent!),
                    textAlign: TextAlign.right,
                    style: percentageStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (table.usedPercent != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ratio = table.usedPercent! / 100;
                    // A two-pixel marker distinguishes positive usage from zero.
                    // Labels and accessibility retain the measured percentage.
                    final visibleRatio = ratio > 0 && constraints.maxWidth > 0
                        ? math
                              .max(ratio, 2 / constraints.maxWidth)
                              .clamp(0.0, 1.0)
                        : ratio;
                    return LinearProgressIndicator(
                      value: visibleRatio,
                      semanticsValue: _ppePercentLabel(table.usedPercent!),
                      minHeight: 6,
                      color: offline || unavailable
                          ? _mutedOf(context)
                          : _blue.withValues(alpha: 0.65),
                      backgroundColor: _mutedOf(context).withValues(alpha: 0.1),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Status card: identity, connection state, and live rates.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.identity,
    required this.stateLabel,
    required this.stateColor,
    required this.headline,
    required this.detail,
    required this.showTopology,
    required this.onOpenDevices,
    required this.live,
  });

  final String identity;
  final String stateLabel;
  final Color stateColor;
  final String headline;
  final String detail;
  final bool showTopology;
  final VoidCallback onOpenDevices;
  final LiveRate? live;

  @override
  Widget build(BuildContext context) {
    final rate = live;
    final ready = rate != null && rate.ready;
    final downText = ready ? formatRate(rate.downBytesPerSecond) : '—';
    final upText = ready ? formatRate(rate.upBytesPerSecond) : '—';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _mutedOf(context),
                  ),
                ),
              ),
              _Pill(stateLabel, stateColor),
            ],
          ),
          const SizedBox(height: 16),
          if (showTopology)
            _NetworkTopology(onOpenDevices: onOpenDevices)
          else
            Text(
              headline,
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: _inkOf(context),
              ),
            ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: _mutedOf(context),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: '实时下载',
                  value: downText,
                  icon: Icons.south_rounded,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: '实时上传',
                  value: upText,
                  icon: Icons.north_rounded,
                  color: _violet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkTopology extends StatelessWidget {
  const _NetworkTopology({required this.onOpenDevices});

  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    final neutral = _mutedOf(context);
    final vertical = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final nodes = [
      _TopologyNode(
        label: '设备',
        icon: Icons.devices_rounded,
        color: neutral,
        onTap: onOpenDevices,
        key: const ValueKey('topology-devices'),
      ),
      const _TopologyNode(label: 'MT7988', color: _green, router: true),
      _TopologyNode(label: '互联网', icon: Icons.public_rounded, color: neutral),
    ];
    return Semantics(
      label: '设备、MT7988、互联网拓扑示意；已连接 MT7988，上游状态未检测',
      child: vertical
          ? Column(
              children: [
                nodes[0],
                _TopologyLink(color: neutral, vertical: true),
                nodes[1],
                _TopologyLink(color: neutral, vertical: true),
                nodes[2],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: nodes[0]),
                Expanded(child: _TopologyLink(color: neutral)),
                Expanded(child: nodes[1]),
                Expanded(child: _TopologyLink(color: neutral)),
                Expanded(child: nodes[2]),
              ],
            ),
    );
  }
}

class _TopologyNode extends StatelessWidget {
  const _TopologyNode({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.router = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool router;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child:
              onTap != null && Theme.of(context).platform == TargetPlatform.iOS
              ? _AppleSymbol(
                  router ? 'wifi' : 'desktopcomputer',
                  fallback: icon ?? Icons.router_rounded,
                  size: 27,
                  color: color,
                )
              : router
              ? _RouterTopologyGlyph(color: color)
              : Icon(icon, size: 27, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _inkOf(context),
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: child,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class _TopologyLink extends StatelessWidget {
  const _TopologyLink({required this.color, this.vertical = false});

  final Color color;
  final bool vertical;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: vertical
        ? Container(
            width: 2,
            height: 18,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: color.withValues(alpha: 0.45),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: color.withValues(alpha: 0.45),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: color.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
  );
}

class _RouterTopologyGlyph extends StatelessWidget {
  const _RouterTopologyGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 27,
    child: Stack(
      children: [
        Positioned(
          left: 6,
          top: 1,
          child: Container(width: 2, height: 8, color: color),
        ),
        Positioned(
          right: 6,
          top: 1,
          child: Container(width: 2, height: 8, color: color),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            width: 30,
            height: 19,
            padding: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 1.5, backgroundColor: color),
                const SizedBox(width: 4),
                CircleAvatar(radius: 1.5, backgroundColor: color),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String _uptime(int? seconds) {
  if (seconds == null) return '—';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  return days > 0 ? '$days 天 $hours 小时' : '$hours 小时';
}

String _sfpStatus(SfpPort port, {bool showTemperature = true}) {
  final status = _sfpLinkStatus(port);
  final temperature = showTemperature ? port.temperatureCelsius : null;
  return '$status · ${temperature == null ? '—' : '${temperature.toStringAsFixed(1)}°C'}';
}

String _sfpLinkStatus(SfpPort port) {
  if (port.linkUp == null) return '状态未获取';
  if (!port.linkUp!) return '未连接';
  final speed = port.speedMbps;
  if (speed == null) return '已连接';
  if (speed < 1000) return '$speed Mb/s';
  return '${(speed / 1000).toStringAsFixed(speed % 1000 == 0 ? 0 : 1)} Gb/s';
}
