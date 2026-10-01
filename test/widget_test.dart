import 'package:flutter/material.dart';
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

void main() {
  testWidgets('offline shell presents connection and all four sections',
      (tester) async {
    await tester.pumpWidget(const ImmortalWrtApp());
    await tester.pump();
    expect(find.text('连接路由器'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('总览'), findsWidgets);
    expect(find.text('设备'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('流量'), findsOneWidget);
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
