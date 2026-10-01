import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/router_models.dart';
import 'services/router_api.dart';

void main() => runApp(const ImmortalWrtApp());

const _blue = Color(0xFF2563EB);
const _violet = Color(0xFF8B5CF6);
const _green = Color(0xFF21A67A);

class ImmortalWrtApp extends StatelessWidget {
  const ImmortalWrtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImmortalWrt',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _blue, surface: const Color(0xFFF5F7FB)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F7FB), centerTitle: false),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme:
            ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.dark),
      ),
      home: const RouterHome(),
    );
  }
}

class RouterHome extends StatefulWidget {
  const RouterHome({super.key});

  @override
  State<RouterHome> createState() => _RouterHomeState();
}

class _RouterHomeState extends State<RouterHome> {
  static const _storage = FlutterSecureStorage();
  RouterApi? _api;
  RouterSnapshot? _snapshot;
  Timer? _timer;
  String? _error;
  bool _loading = false;
  int _tab = 0;
  String _url = 'https://bananapi.x.ddnsto.com';
  String _username = 'root';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final values = await Future.wait([
        _storage.read(key: 'router_url'),
        _storage.read(key: 'router_username'),
        _storage.read(key: 'router_password'),
      ]);
      if (!mounted) return;
      _url = values[0] ?? _url;
      _username = values[1] ?? _username;
      if (values[2] != null) {
        await _connect(_url, _username, values[2]!, save: false);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取保存的连接设置');
    }
  }

  Future<void> _connect(String url, String username, String password,
      {bool save = true}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    RouterApi? next;
    try {
      next = RouterApi(RouterApi.validateUrl(url));
      await next.login(username, password);
      final first = await next.fetch();
      if (!mounted) {
        next.close();
        return;
      }
      if (save) {
        await _storage.write(key: 'router_url', value: url);
        await _storage.write(key: 'router_username', value: username);
        await _storage.write(key: 'router_password', value: password);
      }
      if (!mounted) {
        next.close();
        return;
      }
      _timer?.cancel();
      _api?.close();
      _api = next;
      next = null;
      _url = url;
      _username = username;
      setState(() {
        _snapshot = first;
        _loading = false;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    } catch (error) {
      next?.close();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _refresh() async {
    final api = _api;
    if (api == null || _loading) return;
    try {
      final data = await api.fetch();
      if (mounted && identical(api, _api)) {
        setState(() {
          _snapshot = data;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && identical(api, _api)) setState(() => _error = '$error');
    }
  }

  Future<void> _disconnect() async {
    _timer?.cancel();
    _api?.close();
    _api = null;
    await Future.wait([
      _storage.delete(key: 'router_url'),
      _storage.delete(key: 'router_username'),
      _storage.delete(key: 'router_password'),
    ]);
    if (mounted) {
      setState(() {
        _snapshot = null;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api?.close();
    super.dispose();
  }

  Future<void> _showConnection() async {
    final url = TextEditingController(text: _url);
    final username = TextEditingController(text: _username);
    final password = TextEditingController();
    final request = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 4, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('连接路由器',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('家外通过 HTTPS 入口连接；在家也可改用 192.168.2.1。无需在手机上连接 VPN。'),
                const SizedBox(height: 20),
                TextField(
                    controller: url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                        labelText: '远程 HTTPS 或本地地址',
                        hintText: 'https://bananapi.x.ddnsto.com',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: username,
                    decoration: const InputDecoration(
                        labelText: '用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: '密码', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                const Text(
                    '远程入口需要转发 /ubus。使用本地 HTTP 时密码以明文传输；建议在路由器上创建仅有读取权限的账号。',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: () => Navigator.pop(sheetContext,
                        (url.text.trim(), username.text.trim(), password.text)),
                    child: const Text('连接')),
                if (_snapshot != null)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _disconnect();
                      },
                      child: const Text('退出并清除凭据')),
              ],
            ),
          ),
        ),
      ),
    );
    if (request != null) await _connect(request.$1, request.$2, request.$3);
  }

  @override
  Widget build(BuildContext context) {
    const names = ['总览', '设备', 'Wi-Fi', '流量'];
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: Text(names[_tab],
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              tooltip: '刷新',
              onPressed: _api == null ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: '连接设置',
              onPressed: _showConnection,
              icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: SafeArea(
        child: snapshot == null
            ? _EmptyConnection(
                loading: _loading, error: _error, onConnect: _showConnection)
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    if (_error != null)
                      _Notice('连接中断 · 显示上次成功读取的数据\n$_error',
                          Icons.wifi_off_rounded),
                    if (_tab == 0)
                      _Overview(
                          snapshot: snapshot,
                          endpoint: _url,
                          onOpen: (tab) => setState(() => _tab = tab)),
                    if (_tab == 1) _Devices(snapshot: snapshot),
                    if (_tab == 2) _Wifi(snapshot: snapshot),
                    if (_tab == 3) _Traffic(snapshot: snapshot),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: '总览'),
          NavigationDestination(
              icon: Icon(Icons.devices_outlined),
              selectedIcon: Icon(Icons.devices_rounded),
              label: '设备'),
          NavigationDestination(
              icon: Icon(Icons.wifi_outlined),
              selectedIcon: Icon(Icons.wifi_rounded),
              label: 'Wi-Fi'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_rounded), label: '流量'),
        ],
      ),
    );
  }
}

class _EmptyConnection extends StatelessWidget {
  const _EmptyConnection(
      {required this.loading, required this.error, required this.onConnect});
  final bool loading;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.router_rounded,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text('你的 MT7988，一目了然',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('连接家中的 ImmortalWrt，查看设备、BE14 Wi-Fi 与流量状态。',
            textAlign: TextAlign.center),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(error!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 24),
        if (loading)
          const CircularProgressIndicator()
        else
          FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('连接路由器')),
      ]),
    ));
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, this.icon);
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SurfaceCard(
            child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message))
        ])),
      );
}

class _Overview extends StatelessWidget {
  const _Overview(
      {required this.snapshot, required this.endpoint, required this.onOpen});
  final RouterSnapshot snapshot;
  final String endpoint;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final live = snapshot.live;
    final age = summary?.collectedAt == null
        ? null
        : DateTime.now().difference(summary!.collectedAt!);
    final stale = age != null && age > const Duration(seconds: 60);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.circle, color: _green, size: 11),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                endpoint.startsWith('https://')
                    ? 'MT7988 · 远程连接'
                    : 'MT7988 · 本地连接',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(
            '${snapshot.fetchedAt.hour.toString().padLeft(2, '0')}:${snapshot.fetchedAt.minute.toString().padLeft(2, '0')} 更新',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 14),
      if (stale) const _Notice('Traffic 采集已超过 60 秒未更新', Icons.schedule_rounded),
      _SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('实时 WAN 流量',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: _Metric(
                  label: '下载',
                  value: live?.ready == true
                      ? formatRate(live!.downBytesPerSecond)
                      : '—',
                  icon: Icons.south_rounded,
                  color: _blue)),
          Expanded(
              child: _Metric(
                  label: '上传',
                  value: live?.ready == true
                      ? formatRate(live!.upBytesPerSecond)
                      : '—',
                  icon: Icons.north_rounded,
                  color: _violet)),
        ]),
        const SizedBox(height: 20),
        Text('本次采集会话 · ${summary?.headlineSource ?? '无数据'}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
            summary == null
                ? '—'
                : formatBytes(summary.headlineDown + summary.headlineUp),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ])),
      const SizedBox(height: 12),
      _SurfaceCard(
          child: Column(children: [
        _InfoRow(
            icon: Icons.devices_rounded,
            label: '有流量记录的设备',
            value: summary == null ? '—' : '${summary.clientCount}',
            onTap: () => onOpen(1)),
        const Divider(height: 24),
        _InfoRow(
            icon: Icons.wifi_rounded,
            label: 'BE14 无线状态',
            value: snapshot.wifiError != null
                ? '不可用'
                : '${snapshot.radios.where((r) => r.up).length} 个射频已启用',
            onTap: () => onOpen(2)),
        const Divider(height: 24),
        _InfoRow(
            icon: Icons.show_chart_rounded,
            label: '应用流量',
            value: summary == null ? '不可用' : '${summary.apps.length} 项',
            onTap: () => onOpen(3)),
      ])),
      const SizedBox(height: 12),
      _SurfaceCard(
          child: _InfoRow(
              icon: Icons.memory_rounded,
              label: '系统运行时间',
              value: _uptime(snapshot.uptimeSeconds))),
      if (snapshot.trafficError != null)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _Notice(
                'Traffic App 当前不可用，请确认已安装并授权读取', Icons.info_outline_rounded)),
    ]);
  }
}

String _uptime(int? seconds) {
  if (seconds == null) return '—';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  return days > 0 ? '$days 天 $hours 小时' : '$hours 小时';
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium)
        ]),
        const SizedBox(height: 8),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w800))),
      ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, size: 20),
            ])),
      );
}

class _Devices extends StatelessWidget {
  const _Devices({required this.snapshot});
  final RouterSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final clients = snapshot.summary?.clients ?? const <TrafficClient>[];
    final byIp = {for (final client in clients) client.ip: client};
    final leases = snapshot.dhcpDevices;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('设备',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      const Text('DHCP 租约与 Traffic App 流量记录；租约不表示设备此刻在线。'),
      const SizedBox(height: 16),
      if (leases.isEmpty && clients.isEmpty)
        const _SurfaceCard(child: Text('暂无 DHCP 租约或设备流量数据。')),
      for (final device in leases)
        _DeviceCard(
            name: device.name,
            ip: device.ip,
            mac: device.mac,
            bytes: byIp.remove(device.ip)?.bytes),
      for (final client in byIp.values)
        _DeviceCard(name: client.name, ip: client.ip, bytes: client.bytes),
    ]);
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard(
      {required this.name, required this.ip, this.mac, this.bytes});
  final String name;
  final String ip;
  final String? mac;
  final int? bytes;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _SurfaceCard(
            child: Row(children: [
          CircleAvatar(
              backgroundColor: _blue.withValues(alpha: 0.12),
              child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(mac == null || mac!.isEmpty ? ip : '$ip · $mac',
                    style: Theme.of(context).textTheme.bodySmall)
              ])),
          Text(bytes == null ? '—' : formatBytes(bytes!),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
      );
}

class _Wifi extends StatelessWidget {
  const _Wifi({required this.snapshot});
  final RouterSnapshot snapshot;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('MT7988 · BE14',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('仅显示路由器报告的无线状态，不包含 MiWiFi。'),
        const SizedBox(height: 16),
        if (snapshot.wifiError != null)
          _Notice('无线状态暂不可用：${snapshot.wifiError}', Icons.wifi_off_rounded),
        if (snapshot.radios.isEmpty && snapshot.wifiError == null)
          const _SurfaceCard(
              child: Text('路由器没有返回无线射频数据；厂商 BE14 驱动可能未通过标准 ubus 暴露状态。')),
        for (final radio in snapshot.radios)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SurfaceCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Icon(Icons.wifi_rounded,
                          color: radio.up ? _green : Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(radio.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold))),
                      Text(radio.up ? '已启用' : '已停用',
                          style:
                              TextStyle(color: radio.up ? _green : Colors.grey))
                    ]),
                    const SizedBox(height: 14),
                    Text(radio.ssids.isEmpty
                        ? 'SSID 暂无数据'
                        : radio.ssids.join(' · ')),
                    const SizedBox(height: 8),
                    Text('关联客户端：${radio.clientCount?.toString() ?? '未提供'}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]))),
      ]);
}

class _Traffic extends StatelessWidget {
  const _Traffic({required this.snapshot});
  final RouterSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final apps = summary?.apps ?? const <TrafficApp>[];
    final series = snapshot.series;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('流量趋势',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      const Text('最近 1 小时 · 每个采样点按实际区间换算为速率'),
      const SizedBox(height: 16),
      _SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: 150,
            width: double.infinity,
            child: series?.points.isNotEmpty == true
                ? CustomPaint(painter: _SeriesPainter(series!.points))
                : const Center(child: Text('暂无趋势数据'))),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.circle, size: 11, color: _blue),
          SizedBox(width: 6),
          Text('下载'),
          SizedBox(width: 20),
          Icon(Icons.circle, size: 11, color: _violet),
          SizedBox(width: 6),
          Text('上传')
        ]),
      ])),
      const SizedBox(height: 12),
      _SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('本次采集会话',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(
            summary == null
                ? '暂无数据'
                : '${formatBytes(summary.headlineDown + summary.headlineUp)} · ${summary.headlineSource}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
            summary == null
                ? ''
                : '应用可归属：${formatBytes(summary.attributedDown + summary.attributedUp)}。下方仅列出已识别应用。',
            style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(height: 12),
      Text('应用与站点',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (apps.isEmpty) const _SurfaceCard(child: Text('暂无可识别的应用流量。')),
      for (final app in apps.take(30))
        Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SurfaceCard(
                child: Row(children: [
              CircleAvatar(
                  backgroundColor: _violet.withValues(alpha: 0.13),
                  child: Text(app.name.characters.first.toUpperCase())),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(app.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(formatBytes(app.bytes),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]))),
    ]);
  }
}

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter(this.points);
  final List<TrafficPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final grid = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxValue = points.fold<double>(1, (max, point) {
      final pointMax = point.downBytesPerSecond > point.upBytesPerSecond
          ? point.downBytesPerSecond
          : point.upBytesPerSecond;
      return pointMax > max ? pointMax : max;
    });
    void line(double Function(TrafficPoint) value, Color color) {
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
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    line((point) => point.downBytesPerSecond, _blue);
    line((point) => point.upBytesPerSecond, _violet);
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) =>
      oldDelegate.points != points;
}
