part of '../main.dart';

class _ConnectionSheet extends StatefulWidget {
  const _ConnectionSheet({
    required this.url,
    required this.username,
    required this.connected,
    required this.onDisconnect,
  });

  final String url;
  final String username;
  final bool connected;
  final VoidCallback onDisconnect;

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  late final TextEditingController _url;
  late final TextEditingController _username;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.url);
    _username = TextEditingController(text: widget.username);
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      4,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '连接路由器',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '远程 HTTPS / 本地 HTTP（明文）',
                hintText: 'https://bananapi.x.ddnsto.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                _url.text.trim(),
                _username.text.trim(),
                _password.text,
              )),
              child: const Text('连接'),
            ),
            if (widget.connected)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDisconnect();
                },
                child: const Text('退出并清除凭据'),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

/// Rounded white surface used by every card on every screen.
class _Card extends StatelessWidget {
  const _Card({this.padding = const EdgeInsets.all(18), required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _cardOf(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _borderOf(context)),
      boxShadow: _isDark(context)
          ? null
          : const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
    ),
    child: child,
  );
}

/// Hairline divider that follows the card border tone.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: _borderOf(context));
}

/// Section header: bold title left, small grey qualifier right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trail,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? trail;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title, style: _titleStyle(context))),
        if (trail != null)
          Text(
            trail!,
            style: TextStyle(fontSize: 11.5, color: _mutedOf(context)),
          ),
      ],
    ),
  );
}

/// Small page subtitle under the app bar title.
class _Lead extends StatelessWidget {
  const _Lead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(text, style: _bodyStyle(context)),
  );
}

/// Status pill: tinted rounded background with a saturated label.
class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

/// Rounded two-letter avatar chip.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: _isDark(context) ? 0.24 : 0.12),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

/// Circular icon action for the app bar, matching the card surfaces.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: _cardOf(context),
          clipBehavior: Clip.antiAlias,
          shape: CircleBorder(side: BorderSide(color: _borderOf(context))),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 19,
                color: enabled ? _inkOf(context) : _mutedOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big-figure block: label with icon, large numeral, optional time scope.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _mutedOf(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: _figureStyle(context, color: color)),
        ),
        if (text != null) ...[
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: _mutedOf(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// [_Metric] wrapped in its own card.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.all(16),
    child: _Metric(
      label: label,
      value: value,
      icon: icon,
      color: color,
      caption: caption,
    ),
  );
}

/// Tappable label/value row with a tinted icon chip.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _inkOf(context),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _inkOf(context),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _mutedOf(context),
            ),
        ],
      ),
    ),
  );
}

/// Explicit warning / unavailable banner. Never silently hides a failure.
class _Notice extends StatelessWidget {
  const _Notice(this.message, this.icon, {this.tone = _amber});

  final String message;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _Card(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: _inkOf(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Download / upload legend shared by both charts.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: _mutedOf(context),
    );
    return Row(
      children: [
        const Icon(Icons.circle, size: 10, color: _blue),
        const SizedBox(width: 6),
        Text('下载', style: style),
        const SizedBox(width: 18),
        const Icon(Icons.circle, size: 10, color: _violet),
        const SizedBox(width: 6),
        Text('上传', style: style),
      ],
    );
  }
}

/// Chart frame with an explicit placeholder when no series was returned.
class _TrafficChart extends StatelessWidget {
  const _TrafficChart({required this.series});

  final TrafficSeries? series;

  @override
  Widget build(BuildContext context) {
    final points = series?.points ?? const <TrafficPoint>[];
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: points.length > 1
          ? CustomPaint(painter: _SeriesPainter(points))
          : Center(child: Text('暂无趋势数据', style: _bodyStyle(context))),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline shell
// ---------------------------------------------------------------------------

class _EmptyConnection extends StatelessWidget {
  const _EmptyConnection({
    required this.loading,
    required this.error,
    required this.onConnect,
  });

  final bool loading;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.router_rounded, size: 38, color: _blue),
            ),
            const SizedBox(height: 22),
            Text(
              '连接 MT7988',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _inkOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '仅读取状态 · 凭据保存在本机',
              textAlign: TextAlign.center,
              style: _bodyStyle(context),
            ),
            if (failure != null) ...[
              const SizedBox(height: 16),
              _Notice(failure, Icons.error_outline_rounded, tone: _red),
            ],
            const SizedBox(height: 22),
            if (loading)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('正在读取路由器状态…', style: _bodyStyle(context)),
                ],
              )
            else
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link_rounded),
                label: const Text('连接路由器'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
