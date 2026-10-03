import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models/router_models.dart';
import 'services/router_api.dart';
import 'services/router_session.dart';
import 'services/traffic_icons.dart';

part 'widgets/shared.dart';
part 'widgets/platform_navigation.dart';
part 'screens/overview.dart';
part 'screens/devices.dart';
part 'screens/wifi.dart';
part 'screens/traffic.dart';

void main() => runApp(const ImmortalWrtApp());

// ---------------------------------------------------------------------------
// Design tokens. Accents are shared by every screen; the neutral tones are
// resolved per brightness so dark mode keeps the same hierarchy.
// ---------------------------------------------------------------------------

const _blue = Color(0xFF2563EB);
const _violet = Color(0xFF8B5CF6);
const _green = Color(0xFF21A67A);

const _page = Color(0xFFF4F5F7);
const _ink = Color(0xFF111827);
const _slate = Color(0xFF64748B);
const _amber = Color(0xFFB45309);
const _red = Color(0xFFB42318);
const _pageDark = Color(0xFF0E1014);
const _cardDark = Color(0xFF191C22);
const _borderLight = Color(0xFFE8EAEE);
const _borderDark = Color(0xFF262A32);
const _inkDark = Color(0xFFF3F4F6);
const _slateDark = Color(0xFF94A3B8);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _pageOf(BuildContext context) => _isDark(context) ? _pageDark : _page;
Color _cardOf(BuildContext context) =>
    _isDark(context) ? _cardDark : Colors.white;
Color _borderOf(BuildContext context) =>
    _isDark(context) ? _borderDark : _borderLight;
Color _inkOf(BuildContext context) => _isDark(context) ? _inkDark : _ink;
Color _mutedOf(BuildContext context) => _isDark(context) ? _slateDark : _slate;

TextStyle _titleStyle(BuildContext context) => TextStyle(
  fontSize: 16.5,
  fontWeight: FontWeight.w700,
  color: _inkOf(context),
);

TextStyle _bodyStyle(BuildContext context) =>
    TextStyle(fontSize: 13, height: 1.45, color: _mutedOf(context));

TextStyle _figureStyle(
  BuildContext context, {
  Color? color,
  double size = 30,
}) => TextStyle(
  fontSize: size,
  height: 1.05,
  fontWeight: FontWeight.w800,
  color: color ?? _inkOf(context),
);

/// First two characters of a name, used by the rounded avatar chips.
String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final letters = trimmed.characters.take(2).toList().join().toUpperCase();
  return letters.isEmpty ? '?' : letters;
}

/// A single initial, for the application chips: the mockup renders those as one
/// letter (Y for YouTube, A for Apple) rather than the first two characters.
String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

/// Radio band as reported by the router. Unknown strings are shown verbatim
/// rather than mapped onto a guess; null means the payload carried no band.
String? _bandLabel(String? band) {
  final value = band?.trim().toLowerCase() ?? '';
  if (value.isEmpty) return null;
  if (value == '2g' || value == '2.4g' || value == '2.4ghz' || value == '11g') {
    return '2.4 GHz';
  }
  if (value == '5g' || value == '5ghz' || value == '11a') return '5 GHz';
  if (value == '6g' || value == '6ghz') return '6 GHz';
  return band;
}

class ImmortalWrtApp extends StatefulWidget {
  const ImmortalWrtApp({super.key});

  @override
  State<ImmortalWrtApp> createState() => _ImmortalWrtAppState();
}

class _ImmortalWrtAppState extends State<ImmortalWrtApp> {
  static const _appearance = MethodChannel('com.medyma.immortalwrt/appearance');
  Color? _systemSeed;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _loadSystemAccent();
    }
  }

  Future<void> _loadSystemAccent() async {
    try {
      final value = await _appearance.invokeMethod<int>('accentColor');
      if (mounted && value != null) setState(() => _systemSeed = Color(value));
    } on MissingPluginException {
      // A host without the Android channel keeps the application seed.
    } on PlatformException {
      // A device without a dynamic accent keeps the application seed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = _systemSeed ?? _blue;
    return MaterialApp(
      title: 'ImmortalWrt',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _page,
        appBarTheme: const AppBarTheme(
          backgroundColor: _page,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: _cardDark,
        ),
        scaffoldBackgroundColor: _pageDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: _pageDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _cardDark,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const RouterHome(),
    );
  }
}

class RouterHome extends StatefulWidget {
  const RouterHome({
    super.key,
    this.storage = const FlutterSecureStorage(),
    this.apiFactory,
  });

  final FlutterSecureStorage storage;
  final RouterApi Function(Uri)? apiFactory;

  @override
  State<RouterHome> createState() => _RouterHomeState();
}

class _RouterHomeState extends State<RouterHome> with WidgetsBindingObserver {
  FlutterSecureStorage get _storage => widget.storage;
  RouterApi? _api;
  RouterSnapshot? _snapshot;
  Timer? _timer;
  String? _error;
  bool _loading = false;
  bool _foreground = true;
  bool _checking = false;
  bool _requiresLogin = false;
  bool _refreshing = false;
  DateTime? _lastFullRefresh;
  int _requestVersion = 0;
  int _tab = 0;
  String _url = 'https://bananapi.x.ddnsto.com';
  String _username = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  RouterSection get _section => switch (_tab) {
    1 => RouterSection.devices,
    2 => RouterSection.wifi,
    3 => RouterSection.traffic,
    _ => RouterSection.overview,
  };

  void _startPolling() {
    _timer?.cancel();
    if (_foreground && _api != null && !_requiresLogin) {
      _timer = Timer.periodic(Duration(seconds: _tab == 0 ? 1 : 15), (_) {
        final recent =
            _tab == 0 &&
            _lastFullRefresh != null &&
            DateTime.now().difference(_lastFullRefresh!) <
                const Duration(seconds: 15);
        if (!recent || _snapshot?.liveUnavailable != true) {
          _refresh(liveOnly: recent);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (!resumed) {
      _foreground = false;
      _requestVersion++;
      _timer?.cancel();
      return;
    }
    _foreground = true;
    _startPolling();
    if (_api != null && !_requiresLogin) {
      setState(() => _checking = true);
      _refresh();
    }
  }

  void _selectTab(int tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _checking = _api != null;
    });
    if (_loading) return;
    _requestVersion++;
    _startPolling();
    _refresh();
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

  Future<void> _connect(
    String url,
    String username,
    String password, {
    bool save = true,
  }) async {
    final version = ++_requestVersion;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    RouterApi? next;
    try {
      final uri = RouterApi.validateUrl(url);
      next = widget.apiFactory?.call(uri) ?? RouterApi(uri);
      await next.login(username, password);
      final firstSection = _section;
      final first = await next.fetch(section: firstSection);
      if (!mounted || version != _requestVersion) {
        next.close();
        return;
      }
      if (save) {
        await _storage.write(key: 'router_url', value: url);
        await _storage.write(key: 'router_username', value: username);
        await _storage.write(key: 'router_password', value: password);
      }
      if (!mounted || version != _requestVersion) {
        next.close();
        return;
      }
      _timer?.cancel();
      _api?.close();
      _api = next;
      next = null;
      _url = url;
      _username = username;
      _requiresLogin = false;
      _lastFullRefresh = DateTime.now();
      setState(() {
        _snapshot = first;
        _loading = false;
        _checking = false;
        _error = null;
      });
      _startPolling();
      if (firstSection != _section) _refresh();
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

  Future<void> _refresh({bool liveOnly = false}) async {
    final api = _api;
    if (api == null || _loading || !_foreground || _requiresLogin) return;
    if (_refreshing) return;
    _refreshing = true;
    final requestedTab = _tab;
    final version = ++_requestVersion;
    final section = liveOnly ? RouterSection.live : _section;
    try {
      final session = RouterSession(api, () async {
        final username = await _storage.read(key: 'router_username');
        final password = await _storage.read(key: 'router_password');
        if (username == null || password == null) return null;
        return RouterCredentials(username, password);
      });
      final data = await session.fetch(section, previous: _snapshot);
      if (mounted &&
          _foreground &&
          version == _requestVersion &&
          identical(api, _api)) {
        setState(() {
          _snapshot = data;
          _error = null;
          _checking = false;
          if (!liveOnly) _lastFullRefresh = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted &&
          _foreground &&
          version == _requestVersion &&
          identical(api, _api)) {
        final auth =
            error is RouterPermissionException ||
            error is RouterAccessDeniedException ||
            error is RouterSessionExpiredException ||
            '$error'.contains('登录失败') ||
            '$error'.contains('重新输入账号密码');
        if (auth) {
          _requiresLogin = true;
          _timer?.cancel();
        }
        setState(() {
          _error = '$error';
          _checking = false;
        });
      }
    } finally {
      _refreshing = false;
      if (mounted && _foreground && requestedTab != _tab) {
        _refresh();
      }
    }
  }

  Future<void> _disconnect() async {
    _requestVersion++;
    _timer?.cancel();
    _api?.close();
    _api = null;
    String? storageError;
    try {
      await Future.wait([
        _storage.delete(key: 'router_url'),
        _storage.delete(key: 'router_username'),
        _storage.delete(key: 'router_password'),
      ]);
    } catch (_) {
      storageError = '连接已断开，但无法清除本机保存的凭据，请检查系统安全存储';
    }
    if (mounted) {
      setState(() {
        _snapshot = null;
        _error = storageError;
        _loading = false;
        _checking = false;
        _requiresLogin = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _api?.close();
    super.dispose();
  }

  Future<void> _showConnection() async {
    final request = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConnectionSheet(
        url: _url,
        username: _username,
        connected: _snapshot != null,
        onDisconnect: _disconnect,
      ),
    );
    if (request != null) await _connect(request.$1, request.$2, request.$3);
  }

  @override
  Widget build(BuildContext context) {
    const names = ['总览', '设备', 'Wi-Fi', '流量'];
    final snapshot = _snapshot;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final wide = !isIos && MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: _pageOf(context),
      appBar: AppBar(
        title: Text(
          names[_tab],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          _SettingsAction(onPressed: _showConnection),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: _selectTab,
                labelType: NavigationRailLabelType.all,
                backgroundColor: _cardOf(context),
                indicatorColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: Text('总览'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.devices_outlined),
                    selectedIcon: Icon(Icons.devices_rounded),
                    label: Text('设备'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.router_outlined),
                    selectedIcon: Icon(Icons.router_rounded),
                    label: Text('Wi-Fi'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
                    label: Text('流量'),
                  ),
                ],
              ),
            Expanded(
              child: snapshot == null
                  ? _EmptyConnection(
                      loading: _loading,
                      error: _error,
                      onConnect: _showConnection,
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: _blue,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          if (_error != null)
                            _Notice(
                              '连接中断 · 显示上次成功读取的数据\n$_error',
                              Icons.wifi_off_rounded,
                              tone: _red,
                            ),
                          if (_checking && _error == null)
                            const _Notice(
                              '正在核对数据 · 下方是上次成功读取的状态',
                              Icons.sync_rounded,
                            ),
                          if (_tab == 0)
                            _Overview(
                              snapshot: snapshot,
                              endpoint: _url,
                              error: _error,
                              onOpen: _selectTab,
                            ),
                          if (_tab == 1) _Devices(snapshot: snapshot),
                          if (_tab == 2) _Wifi(snapshot: snapshot),
                          if (_tab == 3)
                            _Traffic(snapshot: snapshot, endpoint: _url),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : isIos
          ? _IosTabBar(selectedIndex: _tab, onSelected: _selectTab)
          : NavigationBar(
              backgroundColor: _cardOf(context),
              indicatorColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '总览',
                ),
                NavigationDestination(
                  icon: Icon(Icons.devices_outlined),
                  selectedIcon: Icon(Icons.devices_rounded),
                  label: '设备',
                ),
                NavigationDestination(
                  icon: Icon(Icons.router_outlined),
                  selectedIcon: Icon(Icons.router_rounded),
                  label: 'Wi-Fi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: '流量',
                ),
              ],
            ),
    );
  }
}
