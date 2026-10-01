part of '../main.dart';

// ---------------------------------------------------------------------------
// Wi-Fi
// ---------------------------------------------------------------------------

class _Wifi extends StatelessWidget {
  const _Wifi({required this.snapshot});

  final RouterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final radios = snapshot.radios;
    final upCount = radios.where((radio) => radio.up).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('BE14 无线', style: _titleStyle(context))),
                  if (radios.isEmpty)
                    _Pill('不可用', _mutedOf(context), tint: 0.16)
                  else if (upCount == 0)
                    _Pill('已停用', _mutedOf(context), tint: 0.16)
                  else
                    const _Pill('运行中', _green),
                ],
              ),
              const SizedBox(height: 8),
              Text(_wifiAvailability(snapshot, radios.length, upCount),
                  style: TextStyle(
                      fontSize: 12.5, height: 1.45, color: _inkOf(context))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '射频状态'),
        if (radios.isEmpty)
          _Card(child: Text('未报告任何射频。', style: _bodyStyle(context))),
        for (final radio in radios) _RadioCard(radio: radio),
      ],
    );
  }
}

/// Never states a radio count the payload did not report.
String _wifiAvailability(RouterSnapshot snapshot, int total, int up) {
  final error = snapshot.wifiError;
  if (error != null) return '无线状态暂不可用：$error';
  if (total == 0) return '路由器没有返回无线射频数据。';
  return '已报告 $total 个射频 · $up 个已启用';
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.radio});

  final WifiRadio radio;

  @override
  Widget build(BuildContext context) {
    final up = radio.up;
    final band = _bandLabel(radio.band);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_rounded,
                    size: 18, color: up ? _green : _mutedOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(radio.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _inkOf(context))),
                ),
                if (up)
                  const _Pill('已启用', _green)
                else
                  _Pill('已停用', _mutedOf(context), tint: 0.16),
              ],
            ),
            const SizedBox(height: 14),
            Text(band ?? '频段未提供',
                style: _figureStyle(context,
                    color: up ? null : _mutedOf(context))),
            const SizedBox(height: 14),
            _DetailLine(
                label: 'SSID',
                value: radio.ssids.isEmpty ? '暂无数据' : radio.ssids.join(' · ')),
            _DetailLine(label: '信道', value: radio.channel?.toString() ?? '未提供'),
            _DetailLine(
                label: '关联设备', value: radio.clientCount?.toString() ?? '未提供'),
          ],
        ),
      ),
    );
  }
}
