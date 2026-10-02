part of '../main.dart';

class _Wifi extends StatefulWidget {
  const _Wifi({required this.snapshot});
  final RouterSnapshot snapshot;
  @override
  State<_Wifi> createState() => _WifiState();
}

class _WifiState extends State<_Wifi> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final radios = widget.snapshot.radios;
    final radio =
        radios.where((r) => r.name == _selected).firstOrNull ??
        radios.where((r) => r.band == '5g').firstOrNull ??
        radios.firstOrNull;
    final points =
        widget.snapshot.wifiHistory?.points
            .where((p) => p.radio == radio?.name)
            .toList(growable: false) ??
        const <WifiPoint>[];
    final lastPoint = points.lastOrNull;
    final latest =
        lastPoint != null &&
            DateTime.now().difference(lastPoint.at) < const Duration(minutes: 3)
        ? lastPoint
        : null;
    final active = radios.where((r) => r.up).length;
    final quality = points.any(
      (p) => p.txFailurePercent != null || p.rxCrcPercent != null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BE14 无线', style: _titleStyle(context)),
                    const SizedBox(height: 5),
                    Text(
                      radios.isEmpty
                          ? '无线状态暂不可用'
                          : '$active/${radios.length} 个射频运行中',
                      style: _bodyStyle(context),
                    ),
                  ],
                ),
              ),
              _Pill(
                active > 0 ? '运行中' : '不可用',
                active > 0 ? _green : _mutedOf(context),
              ),
            ],
          ),
        ),
        if (widget.snapshot.wifiError != null) ...[
          const SizedBox(height: 10),
          _Notice(
            '无线状态暂不可用：${widget.snapshot.wifiError}',
            Icons.info_outline_rounded,
          ),
        ],
        if (radio != null) ...[
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final option in radios)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: _BandButton(
                            label: _bandLabel(option.band) ?? option.name,
                            selected: option.name == radio.name,
                            onTap: () =>
                                setState(() => _selected = option.name),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _bandLabel(radio.band) ?? radio.name,
                        style: _figureStyle(context, size: 27),
                      ),
                    ),
                    Text(
                      radio.channel == null
                          ? '信道 —'
                          : '信道 ${radio.channel} · ${radio.widthMHz == null ? '频宽未提供' : '${radio.widthMHz} MHz'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _mutedOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _Pill(
                      radio.up ? '已启用' : '已停用',
                      radio.up ? _green : _mutedOf(context),
                    ),
                    const SizedBox(width: 8),
                    if (radio.bssid?.isNotEmpty == true)
                      Flexible(
                        child: Text(
                          'BSSID ${radio.bssid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _Hairline(),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _WifiFigure(
                        'TX 失败率',
                        latest?.txFailurePercent,
                        _blue,
                      ),
                    ),
                    Expanded(
                      child: _WifiFigure('接收错误率', latest?.rxCrcPercent, _amber),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: '链路质量',
                  trail: '最近 24 小时',
                  padding: EdgeInsets.zero,
                ),
                if (quality)
                  _WifiChart(
                    points: points,
                    quality: true,
                    interval: widget.snapshot.wifiHistory?.interval ?? 300,
                  )
                else
                  _ChartEmpty('暂无质量历史'),
                const SizedBox(height: 9),
                const _WifiLegend('TX 失败率', '接收错误率', _blue, _amber),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: '无线活动',
                  trail: '最近 24 小时',
                  padding: EdgeInsets.zero,
                ),
                if (points.isNotEmpty)
                  _WifiChart(
                    points: points,
                    quality: false,
                    interval: widget.snapshot.wifiHistory?.interval ?? 300,
                  )
                else
                  _ChartEmpty('暂无活动历史'),
                const SizedBox(height: 9),
                const _WifiLegend('下载', '上传', _blue, _violet),
                const SizedBox(height: 12),
                Text(
                  '当前 ${latest == null ? '—' : formatRate(latest.downBytesPerSecond)} ↓   '
                  '${latest == null ? '—' : formatRate(latest.upBytesPerSecond)} ↑',
                  style: _bodyStyle(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BandButton extends StatelessWidget {
  const _BandButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _blue.withValues(alpha: 0.11) : _pageOf(context),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? _blue : _mutedOf(context),
          ),
        ),
      ),
    ),
  );
}

class _WifiFigure extends StatelessWidget {
  const _WifiFigure(this.label, this.value, this.color);
  final String label;
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _bodyStyle(context)),
      const SizedBox(height: 5),
      Text(
        value == null
            ? '—'
            : '${value!.toStringAsFixed(value! >= 10 ? 0 : 1)}%',
        style: _figureStyle(context, size: 24, color: color),
      ),
    ],
  );
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 128,
    child: Center(child: Text(label, style: _bodyStyle(context))),
  );
}

class _WifiLegend extends StatelessWidget {
  const _WifiLegend(this.first, this.second, this.firstColor, this.secondColor);
  final String first;
  final String second;
  final Color firstColor;
  final Color secondColor;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _item(first, firstColor),
      const SizedBox(width: 18),
      _item(second, secondColor),
    ],
  );
  Widget _item(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _WifiChart extends StatelessWidget {
  const _WifiChart({
    required this.points,
    required this.quality,
    required this.interval,
  });
  final List<WifiPoint> points;
  final bool quality;
  final int interval;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(
          painter: _WifiPainter(points, quality, interval, _borderOf(context)),
        ),
      ),
      const SizedBox(height: 7),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('24 小时前', style: _bodyStyle(context)),
          Text('现在', style: _bodyStyle(context)),
        ],
      ),
    ],
  );
}

class _WifiPainter extends CustomPainter {
  const _WifiPainter(this.points, this.quality, this.interval, this.gridColor);
  final List<WifiPoint> points;
  final bool quality;
  final int interval;
  final Color gridColor;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) return;
    final latest = points.last.at.millisecondsSinceEpoch.toDouble();
    final start = latest - const Duration(hours: 24).inMilliseconds;
    final maxValue = quality
        ? 100.0
        : points.fold<double>(
            1,
            (max, point) => math.max(
              max,
              math.max(point.downBytesPerSecond, point.upBytesPerSecond),
            ),
          );
    void line(double? Function(WifiPoint) getValue, Color color) {
      final path = Path();
      WifiPoint? previous;
      for (final point in points) {
        final value = getValue(point);
        if (value == null || point.at.millisecondsSinceEpoch < start) {
          previous = null;
          continue;
        }
        final x =
            ((point.at.millisecondsSinceEpoch - start) /
                    (latest - start) *
                    size.width)
                .clamp(0.0, size.width);
        final y = size.height - (value / maxValue).clamp(0, 1) * size.height;
        if (previous == null ||
            point.at.difference(previous.at) >
                Duration(seconds: interval * 2)) {
          path.moveTo(x, y);
          canvas.drawCircle(Offset(x, y), 2, Paint()..color = color);
        } else {
          path.lineTo(x, y);
        }
        previous = point;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (quality) {
      line((point) => point.txFailurePercent, _blue);
      line((point) => point.rxCrcPercent, _amber);
    } else {
      line((point) => point.downBytesPerSecond, _blue);
      line((point) => point.upBytesPerSecond, _violet);
    }
  }

  @override
  bool shouldRepaint(covariant _WifiPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.quality != quality ||
      oldDelegate.interval != interval ||
      oldDelegate.gridColor != gridColor;
}
