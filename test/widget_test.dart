import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
}

class _FakeRouterApi extends RouterApi {
  _FakeRouterApi() : super(Uri.parse('https://router.example.com'));
  final sections = <RouterSection>[];

  @override
  Future<void> login(String username, String password) async {}

  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
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
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    reads++;
    if (reads > 1) throw const RouterSessionExpiredException();
    return RouterSnapshot(fetchedAt: DateTime.now());
  }
}

class _NoTrafficApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    sections.add(section);
    return RouterSnapshot(
      fetchedAt: DateTime.now(),
      liveError: 'luci.traffic.getLive 不可用',
      liveUnavailable: true,
    );
  }
}

class _TransientLiveApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    sections.add(section);
    return RouterSnapshot(fetchedAt: DateTime.now(), liveError: '实时速率请求超时');
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
    return RouterSnapshot(
      fetchedAt: DateTime.now(),
      live: const LiveRate(
        ready: true,
        downBytesPerSecond: 1024,
        upBytesPerSecond: 512,
        at: null,
      ),
    );
  }
}

class _HealthyApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    live: const LiveRate(
      ready: true,
      downBytesPerSecond: 1024,
      upBytesPerSecond: 512,
      at: null,
    ),
  );
}

class _PpeApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    ppeTables: const [PpeTable(index: 0, bound: 1024, capacity: 8192)],
    temperatures: [
      RouterTemperature(
        kind: 'cpu',
        name: 'cpu-thermal',
        celsius: 52,
        sampledAt: DateTime.now(),
      ),
      RouterTemperature(
        kind: 'wifi',
        name: 'MT7990',
        celsius: 46,
        sampledAt: DateTime.now(),
      ),
      RouterTemperature(
        kind: 'disk',
        name: 'nvme',
        celsius: 39,
        sampledAt: DateTime.now(),
      ),
    ],
    sfpPorts: const [
      SfpPort(
        interface: 'eth1',
        slot: 'SFP1',
        linkUp: true,
        speedMbps: 2500,
        temperatureCelsius: 47.74,
      ),
    ],
  );
}

class _ManyAppsApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    trafficWindow: TrafficSummary.fromJson({
      'apps': List.generate(
        45,
        (i) => {
          'name': i.isEven ? 'Application $i' : 'site-$i.example.com',
          'bytes': 1000 + i,
        },
      ),
    }),
  );
}

class _WifiApi extends _FakeRouterApi {
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    radios: const [
      WifiRadio(
        name: 'MT7990_1_1',
        up: true,
        ssids: [],
        clientCount: null,
        band: '2g',
        channel: 3,
        htmode: 'EHT40',
      ),
      WifiRadio(
        name: 'MT7990_1_2',
        up: true,
        ssids: [],
        clientCount: null,
        band: '5g',
        channel: 40,
        htmode: 'EHT160',
        bssid: '02:11:22:33:44:55',
      ),
    ],
    wifiHistory: WifiHistory(
      interval: 60,
      points: [
        WifiPoint(
          at: DateTime.now().subtract(const Duration(minutes: 1)),
          radio: 'MT7990_1_2',
          downBytesPerSecond: 1024,
          upBytesPerSecond: 512,
          txFailurePercent: 6,
          rxCrcPercent: 16,
        ),
        WifiPoint(
          at: DateTime.now(),
          radio: 'MT7990_1_2',
          downBytesPerSecond: 2048,
          upBytesPerSecond: 700,
          txFailurePercent: 5,
          rxCrcPercent: 12,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('toolbar has one settings action and no refresh action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RouterHome()));
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('连接设置'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });
  for (final brightness in Brightness.values) {
    testWidgets('overview temperature order and SFP units in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _PpeApi(),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('MT7988 状态'), 250);
      expect(
        tester.getTopLeft(find.text('硬件加速')).dy,
        lessThan(tester.getTopLeft(find.text('MT7988 状态')).dy),
      );
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('BE14'), findsOneWidget);
      expect(find.text('NVMe'), findsOneWidget);
      expect(find.text('52°C'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('2.5 Gb/s · 47.7°C'), 250);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'traffic lists every returned application and site beyond thirty',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _ManyAppsApi(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('流量').last);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Application 44'), 400);
      for (var i = 0; i < 45; i++) {
        expect(
          find.text(i.isEven ? 'Application $i' : 'site-$i.example.com'),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('HNAT card keeps PPE bars without aggregate or footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _PpeApi(),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('HNAT'), 350);
    expect(find.text('PPE 0'), findsOneWidget);
    expect(find.text('1024 / 8192'), findsOneWidget);
    expect(find.text('12.5%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('已绑定流表'), findsNothing);
    expect(find.text('流表占用率'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('long background pause renews session and resumes live polling', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 2);
    var logins = 0;
    var reads = 0;
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      clock: () => now,
      client: MockClient((request) async {
        final p = (jsonDecode(request.body) as Map)['params'] as List;
        if (p[2] == 'login') {
          logins++;
          return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 's$logins', 'timeout': 300},
              ],
            }),
            200,
          );
        }
        reads++;
        return http.Response('{"result":[0,{}]}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    expect(logins, 1);
    final initialReads = reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 22));
    await tester.pump(const Duration(minutes: 22));
    expect(reads, initialReads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(logins, 2);
    expect(reads, greaterThan(initialReads));
    expect(find.textContaining('连接中断'), findsNothing);
    final resumedReads = reads;
    await tester.pump(const Duration(seconds: 1));
    expect(reads, greaterThan(resumedReads));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('partial transient live failure still retries after one second', (
    tester,
  ) async {
    final api = _TransientLiveApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(api.sections, [RouterSection.overview, RouterSection.live]);
  });
  testWidgets(
    'missing traffic does not flood live reads or block Wi-Fi navigation',
    (tester) async {
      final api = _NoTrafficApi();
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(api.sections, [RouterSection.overview]);
      expect(find.textContaining('连接中断 ·'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Wi-Fi'),
        ),
      );
      await tester.pump();
      expect(api.sections.last, RouterSection.wifi);
    },
  );
  testWidgets('overview reads only live rate after one second', (tester) async {
    final api = _FakeRouterApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(api.sections, [RouterSection.overview, RouterSection.live]);
    await tester.tap(find.text('设备').last);
    await tester.pump();
    final count = api.sections.length;
    await tester.pump(const Duration(seconds: 1));
    expect(api.sections.length, count);
  });
  testWidgets('offline shell presents connection and all four sections', (
    tester,
  ) async {
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

  testWidgets('device and BE14 status keep concise scope labels', (
    tester,
  ) async {
    final api = _FakeRouterApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('设备').last);
    await tester.pump();
    expect(find.text('设备记录不代表当前在线'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Wi-Fi'),
      ),
    );
    await tester.pump();
    expect(find.text('BE14 无线'), findsOneWidget);
    expect(find.text('2.4 GHz'), findsNothing);
  });

  testWidgets('Wi-Fi channel view selects 5 GHz and shows measured history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _WifiApi(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Wi-Fi'),
      ),
    );
    await tester.pump();
    expect(find.text('5 GHz'), findsWidgets);
    expect(find.textContaining('40 · 160 MHz'), findsOneWidget);
    expect(find.text('TX FAL'), findsWidgets);
    expect(find.text('RX CRC'), findsWidgets);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('BSSID 02:11:22:33:44:55'), findsOneWidget);
    await tester.tap(find.text('2.4 GHz'));
    await tester.pump();
    expect(find.textContaining('3 · 40 MHz'), findsOneWidget);
    expect(find.text('暂无质量历史'), findsOneWidget);
  });

  testWidgets('healthy overview shows device to router to internet topology', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _HealthyApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('网络运行正常'), findsNothing);
    expect(find.text('MT7988'), findsWidgets);
    expect(find.text('互联网'), findsOneWidget);
    expect(find.text('UCG Fiber'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('topology-devices')));
    await tester.pump();
    expect(find.text('设备记录'), findsOneWidget);
  });

  testWidgets(
    'overview keeps chart on traffic page and device list has no duplicate filter',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _HealthyApi(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('最近 1 小时'), findsNothing);
      expect(find.text('CPU 使用率'), findsOneWidget);
      expect(find.text('内存使用率'), findsOneWidget);
      await tester.tap(find.text('设备').last);
      await tester.pump();
      expect(find.text('全部设备'), findsNothing);
      expect(find.text('有流量记录'), findsNothing);
    },
  );

  testWidgets('iOS presents a platform tab bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _FakeRouterApi(),
          ),
        ),
      );
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
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _FakeRouterApi(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Android uses the system accent when available', (tester) async {
    const channel = MethodChannel('com.medyma.immortalwrt/appearance');
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls++;
      return 0xFFBF5AF2;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(const ImmortalWrtApp());
      await tester.pumpAndSettle();
      expect(calls, 1);
      final theme = Theme.of(tester.element(find.byType(RouterHome)));
      expect(
        theme.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: const Color(0xFFBF5AF2)).primary,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('background pauses polling and resume refreshes visible page', (
    tester,
  ) async {
    final api = _FakeRouterApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    expect(api.sections, [RouterSection.overview]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 16));
    expect(api.sections, [RouterSection.overview]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.sections, [RouterSection.overview, RouterSection.overview]);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Wi-Fi'),
      ),
    );
    await tester.pump();
    expect(api.sections.last, RouterSection.wifi);
  });

  testWidgets('repeated ACL denial stops automatic polling', (tester) async {
    final api = _ExpiringApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
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

  testWidgets('remote interruption keeps stale data and later recovers', (
    tester,
  ) async {
    final api = _FlakyApi();
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    expect(find.text('互联网'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('连接中断 · 显示上次成功读取的数据'), findsOneWidget);
    expect(find.text('连接已中断'), findsOneWidget);
    expect(find.text('互联网'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('连接中断 · 显示上次成功读取的数据'), findsNothing);
    expect(find.text('互联网'), findsOneWidget);
    expect(api.reads, 3);
  });
}
