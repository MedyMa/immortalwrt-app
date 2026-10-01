import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:immortalwrt_app/main.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{
    'router_url': 'https://router.example.com',
    'router_username': 'u',
    'router_password': 'p',
  };

  @override
  Future<String?> read(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      values[key];
}

class _FakeRouterApi extends RouterApi {
  _FakeRouterApi() : super(Uri.parse('https://router.example.com'));
  final sections = <RouterSection>[];

  @override
  Future<void> login(String username, String password) async {}

  @override
  Future<RouterSnapshot> fetch(
      {RouterSection section = RouterSection.all,
      RouterSnapshot? previous}) async {
    sections.add(section);
    return RouterSnapshot(fetchedAt: DateTime.now());
  }
}

class _ExpiringApi extends _FakeRouterApi {
  int logins = 0;
  int reads = 0;

  @override
  Future<void> login(String username, String password) async {
    logins++;
  }

  @override
  Future<RouterSnapshot> fetch(
      {RouterSection section = RouterSection.all,
      RouterSnapshot? previous}) async {
    reads++;
    if (reads > 1) throw const RouterSessionExpiredException();
    return RouterSnapshot(fetchedAt: DateTime.now());
  }
}

class _FlakyApi extends _FakeRouterApi {
  int reads = 0;

  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    reads++;
    if (reads == 2) {
      throw const RouterApiException('连接超时，请检查路由器或远程入口');
    }
    return RouterSnapshot(fetchedAt: DateTime.now());
  }
}

class _HealthyApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async =>
      RouterSnapshot(
        fetchedAt: DateTime.now(),
        live: const LiveRate(
            ready: true,
            downBytesPerSecond: 1024,
            upBytesPerSecond: 512,
            at: null),
      );
}

void main() {
  testWidgets('offline shell presents connection and all four sections',
      (tester) async {
    await tester.pumpWidget(const ImmortalWrtApp());
    await tester.pump();
    expect(find.text('连接路由器'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('总览'), findsWidgets);
    expect(find.text('设备'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('流量'), findsOneWidget);
    expect(find.text('仅读取状态 · 凭据保存在本机'), findsOneWidget);
  });

  testWidgets('device and BE14 status keep concise scope labels',
      (tester) async {
    final api = _FakeRouterApi();
    await tester.pumpWidget(MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api)));
    await tester.pump();
    await tester.tap(find.text('设备').last);
    await tester.pump();
    expect(find.text('设备记录不代表当前在线'), findsOneWidget);
    await tester.tap(find.text('Wi-Fi').last);
    await tester.pump();
    expect(find.text('BE14 驱动可能不返回全部射频'), findsOneWidget);
  });

  testWidgets('healthy network uses a connection icon in the hero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RouterHome(
            storage: _MemoryStorage(), apiFactory: (_) => _HealthyApi())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    expect(find.text('网络运行正常'), findsNothing);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(tester.getSemantics(find.byIcon(Icons.cloud_done_rounded)).label,
        contains('网络连接正常'));
    semantics.dispose();
  });

  testWidgets('iOS presents a platform tab bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(MaterialApp(
          home: RouterHome(
              storage: _MemoryStorage(), apiFactory: (_) => _FakeRouterApi())));
      await tester.pump();
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('wide Android uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: RouterHome(
            storage: _MemoryStorage(), apiFactory: (_) => _FakeRouterApi())));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Android uses the system accent when available', (tester) async {
    const channel = MethodChannel('com.medyma.immortalwrt/appearance');
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls++;
      return 0xFFBF5AF2;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(const ImmortalWrtApp());
      await tester.pumpAndSettle();
      expect(calls, 1);
      final theme = Theme.of(tester.element(find.byType(RouterHome)));
      expect(theme.colorScheme.primary,
          ColorScheme.fromSeed(seedColor: const Color(0xFFBF5AF2)).primary);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('background pauses polling and resume refreshes visible page',
      (tester) async {
    final api = _FakeRouterApi();
    await tester.pumpWidget(MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api)));
    await tester.pump();
    expect(api.sections, [RouterSection.overview]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 16));
    expect(api.sections, [RouterSection.overview]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.sections, [RouterSection.overview, RouterSection.overview]);
    await tester.tap(find.text('Wi-Fi').last);
    await tester.pump();
    expect(api.sections.last, RouterSection.wifi);
  });

  testWidgets('repeated ACL denial stops automatic polling', (tester) async {
    final api = _ExpiringApi();
    await tester.pumpWidget(MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api)));
    await tester.pump();
    expect(api.logins, 1);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(api.logins, 2);
    expect(api.reads, 3);
    await tester.pump(const Duration(seconds: 31));
    expect(api.logins, 2);
    expect(api.reads, 3);
  });

  testWidgets('remote interruption keeps stale data and later recovers',
      (tester) async {
    final api = _FlakyApi();
    await tester.pumpWidget(MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.textContaining('连接中断 · 显示上次成功读取的数据'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.textContaining('连接中断 · 显示上次成功读取的数据'), findsNothing);
    expect(api.reads, 3);
  });
}
