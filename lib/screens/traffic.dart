part of '../main.dart';

// ---------------------------------------------------------------------------
// 流量
// ---------------------------------------------------------------------------

class _Traffic extends StatefulWidget {
  const _Traffic({required this.snapshot, required this.endpoint});

  final RouterSnapshot snapshot;
  final String endpoint;

  @override
  State<_Traffic> createState() => _TrafficState();
}

class _TrafficState extends State<_Traffic> {
  late Future<TrafficIcons> _icons;
  DateTime _iconsLoadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(covariant _Traffic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endpoint != widget.endpoint) {
      _loadIcons();
    } else if (DateTime.now().difference(_iconsLoadedAt).inSeconds >= 60) {
      _iconsLoadedAt = DateTime.now();
      _icons = _icons.then((catalog) => catalog.refreshWebsites());
    }
  }

  void _loadIcons() {
    _iconsLoadedAt = DateTime.now();
    _icons = TrafficIcons.load(Uri.parse(widget.endpoint));
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.snapshot.trafficWindow;
    final series = widget.snapshot.series;
    final points = series?.points ?? const <TrafficPoint>[];
    final double? peak = points.isEmpty ? null : series?.peakBytesPerSecond;
    final apps = summary?.apps ?? const <TrafficApp>[];
    final down = summary?.headlineDown;
    final up = summary?.headlineUp;
    final total = down == null || up == null ? null : down + up;
    final attributedText = summary == null
        ? null
        : formatBytes(summary.attributedDown + summary.attributedUp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: summary == null
                    ? '流量总计'
                    : summary.hasWanTotals
                    ? 'WAN 总流量'
                    : '归属流量',
                trail: '最近 24 小时',
                padding: EdgeInsets.zero,
              ),
              Text(
                total == null ? '—' : formatBytes(total),
                style: _figureStyle(context, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                summary == null
                    ? '未获取到 Traffic App 采集数据'
                    : '来源 ${summary.headlineSource}',
                style: _bodyStyle(context),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '↓ 下载 ',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: down == null ? '—' : formatBytes(down),
                      style: TextStyle(
                        color: _inkOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(
                      text: '    ↑ 上传 ',
                      style: TextStyle(
                        color: _violet,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: up == null ? '—' : formatBytes(up),
                      style: TextStyle(
                        color: _inkOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: '流量波形',
                trail: '最近 24 小时',
                padding: EdgeInsets.zero,
              ),
              _TrafficChart(series: series),
              const SizedBox(height: 12),
              Row(
                children: [
                  const _Legend(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '峰值 ${peak == null ? '—' : formatRate(peak)}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _mutedOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.snapshot.windowError != null) ...[
          const SizedBox(height: 10),
          _Notice(
            '流量统计暂不可用：${widget.snapshot.windowError}',
            Icons.info_outline_rounded,
          ),
        ],
        if (widget.snapshot.seriesError != null) ...[
          const SizedBox(height: 10),
          _Notice(
            '流量曲线暂不可用：${widget.snapshot.seriesError}',
            Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeader(title: '应用与站点', trail: attributedText),
        if (apps.isEmpty)
          _Card(child: Text('暂无可识别的应用流量。', style: _bodyStyle(context)))
        else
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: FutureBuilder<TrafficIcons>(
              future: _icons,
              builder: (context, state) => Column(
                children: [
                  for (var i = 0; i < apps.length; i++) ...[
                    if (i > 0) const _Hairline(),
                    _AppTile(
                      app: apps[i],
                      icon: state.data?.iconUri(apps[i].name),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, this.icon});

  final TrafficApp app;
  final Uri? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        TrafficIcon(name: app.name, uri: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _inkOf(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatBytes(app.bytes),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _inkOf(context),
          ),
        ),
      ],
    ),
  );
}

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter(this.points);
  final List<TrafficPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final grid = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxValue = points.fold<double>(
      1,
      (max, point) => math.max(
        max,
        math.max(point.downBytesPerSecond, point.upBytesPerSecond),
      ),
    );

    Path trace(double Function(TrafficPoint) value) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = size.width * i / (points.length - 1);
        final y = size.height - value(points[i]) / maxValue * (size.height - 8);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    void stroke(Path path, Color color, {bool fill = false}) {
      if (fill) {
        final area = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0),
              ],
            ).createShader(Offset.zero & size),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    stroke(trace((point) => point.downBytesPerSecond), _blue, fill: true);
    stroke(trace((point) => point.upBytesPerSecond), _violet);
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) =>
      oldDelegate.points != points;
}
