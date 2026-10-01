part of '../main.dart';

// ---------------------------------------------------------------------------
// 总览
// ---------------------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview(
      {required this.snapshot,
      required this.endpoint,
      required this.onOpen,
      this.error});

  final RouterSnapshot snapshot;
  final String endpoint;
  final ValueChanged<int> onOpen;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final collected = summary?.collectedAt;
    final age =
        collected == null ? null : snapshot.fetchedAt.difference(collected);
    final stale = age != null && age > const Duration(seconds: 60);
    final offline = error != null;
    final remote = endpoint.startsWith('https://');
    final clock =
        '${snapshot.fetchedAt.hour.toString().padLeft(2, '0')}:${snapshot.fetchedAt.minute.toString().padLeft(2, '0')}';

    final Color stateColor;
    final String stateLabel;
    final String headline;
    final String detail;
    if (offline) {
      stateColor = _red;
      stateLabel = '连接中断';
      headline = '连接已中断';
      detail = '显示上次成功读取的数据';
    } else if (stale) {
      stateColor = _amber;
      stateLabel = '数据延迟';
      headline = '数据更新延迟';
      detail = 'Traffic 采集已超过 60 秒未更新';
    } else if (summary == null && snapshot.live == null) {
      stateColor = _green;
      stateLabel = '已连接';
      headline = '路由器已连接';
      detail = '未获取到 Traffic 采集数据';
    } else {
      stateColor = _green;
      stateLabel = '已连接';
      headline = '网络运行正常';
      detail = '';
    }

    final down = summary?.headlineDown;
    final up = summary?.headlineUp;
    final total = down == null || up == null ? null : down + up;
    final source = summary?.headlineSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Lead('家中网络 · ${remote ? '远程' : '本地'}连接 · $clock 更新'),
        _Hero(
          identity: remote ? 'MT7988 · 远程连接' : 'MT7988 · 本地连接',
          stateLabel: stateLabel,
          stateColor: stateColor,
          headline: headline,
          detail: detail,
          live: snapshot.live,
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
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('最近 1 小时', style: _titleStyle(context))),
                  _TextLink(label: '查看流量', onTap: () => onOpen(3)),
                ],
              ),
              const SizedBox(height: 14),
              _TrafficChart(series: snapshot.series),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          ),
        ),
        if (snapshot.seriesError != null) ...[
          const SizedBox(height: 10),
          _Notice(
              '流量曲线暂不可用：${snapshot.seriesError}', Icons.info_outline_rounded),
        ],
        const SizedBox(height: 20),
        const _SectionHeader(title: '系统状态'),
        _Card(
          child: Column(
            children: [
              _InfoRow(
                  icon: Icons.devices_rounded,
                  label: '有流量记录的设备',
                  value: summary == null ? '—' : '${summary.clientCount}',
                  onTap: () => onOpen(1)),
              const _Hairline(),
              _InfoRow(
                  icon: Icons.wifi_rounded,
                  label: 'BE14 无线状态',
                  value: snapshot.wifiError != null
                      ? '不可用'
                      : '${snapshot.radios.where((radio) => radio.up).length} 个射频已启用',
                  onTap: () => onOpen(2)),
              const _Hairline(),
              _InfoRow(
                  icon: Icons.show_chart_rounded,
                  label: '应用流量',
                  value: summary == null ? '不可用' : '${summary.apps.length} 项',
                  onTap: () => onOpen(3)),
              const _Hairline(),
              _InfoRow(
                  icon: Icons.memory_rounded,
                  label: '系统运行时间',
                  value: _uptime(snapshot.uptimeSeconds)),
            ],
          ),
        ),
        if (snapshot.trafficError != null) ...[
          const SizedBox(height: 12),
          const _Notice(
              'Traffic App 当前不可用，请确认已安装并授权读取', Icons.info_outline_rounded),
        ],
      ],
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
    required this.live,
  });

  final String identity;
  final String stateLabel;
  final Color stateColor;
  final String headline;
  final String detail;
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
                child: Text(identity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _mutedOf(context))),
              ),
              _Pill(stateLabel, stateColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(headline,
              style: TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: _inkOf(context))),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detail,
                style: TextStyle(
                    fontSize: 12.5, height: 1.35, color: _mutedOf(context))),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Metric(
                    label: '实时下载',
                    value: downText,
                    icon: Icons.south_rounded,
                    color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                    label: '实时上传',
                    value: upText,
                    icon: Icons.north_rounded,
                    color: _violet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _uptime(int? seconds) {
  if (seconds == null) return '—';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  return days > 0 ? '$days 天 $hours 小时' : '$hours 小时';
}
