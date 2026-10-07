import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
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

class _PullRefreshApi extends _HealthyApi {
  Completer<RouterSnapshot>? gate;
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    sections.add(section);
    if (section != RouterSection.live && gate != null) return gate!.future;
    return super.fetch(section: section, previous: previous);
  }

  Future<void> release() async {
    final pending = gate!;
    gate = null;
    pending.complete(await super.fetch());
  }
}

class _ChangingLiveApi extends _FakeRouterApi {
  int reads = 0;
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    reads++;
    sections.add(section);
    return RouterSnapshot(
      fetchedAt: DateTime.now(),
      live: LiveRate(
        ready: true,
        downBytesPerSecond: reads * 1024,
        upBytesPerSecond: 512,
        at: null,
      ),
    );
  }
}

class _DeviceIdentityApi extends _HealthyApi {
  _DeviceIdentityApi({this.longValues = false, this.dualStack = false});
  final bool dualStack;
  final bool longValues;
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    live: const LiveRate(
      ready: true,
      downBytesPerSecond: 0,
      upBytesPerSecond: 0,
      at: null,
    ),
    hostHints: dualStack
        ? const [
            HostHint(
              mac: '02:11:22:33:44:55',
              name: '',
              addresses: [
                '192.168.2.114',
                '240e:1234:5678:9abc:1111:2222:3333:4444',
                'fd00::1',
              ],
            ),
          ]
        : const [],
    summary: dualStack
        ? TrafficSummary.fromJson({
            'clients': [
              {'ip': '192.168.2.114', 'bytes': 100},
              {'ip': '240e:1234:5678:9abc:1111:2222:3333:4444', 'bytes': 200},
            ],
          })
        : null,
    dhcpDevices: longValues
        ? const [
            DhcpDevice(
              name: 'Galaxy-Z-Flip-living-room-personal-device',
              ip: 'fdc8:64ed:f962:0000:0000:0000:0000:0d1c',
              mac: '02:11:22:33:44:55',
            ),
          ]
        : const [
            DhcpDevice(
              name: 'MZYtekiiPhone',
              ip: '192.168.2.114',
              mac: '02:11:22:33:44:55',
            ),
            DhcpDevice(name: '192.168.2.115', ip: '192.168.2.115', mac: ''),
          ],
  );
}

class _PpeApi extends _FakeRouterApi {
  _PpeApi({
    this.tables = const [PpeTable(index: 0, bound: 1024, capacity: 8192)],
  });
  final List<PpeTable> tables;
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    ppeTables: tables,
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
  for (final brightness in Brightness.values) {
    testWidgets('iOS $brightness initial loading uses Apple indicator', (
      tester,
    ) async {
      final api = _PullRefreshApi()..gate = Completer<RouterSnapshot>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            brightness: brightness,
          ),
          home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
        ),
      );
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await api.release();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Android initial loading retains Material indicator', (
    tester,
  ) async {
    final api = _PullRefreshApi()..gate = Completer<RouterSnapshot>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    await api.release();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final page in ['设备', 'Wi-Fi', '流量']) {
    testWidgets('iOS $page data recheck uses Apple indicator', (tester) async {
      final api = _PullRefreshApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
        ),
      );
      await tester.pumpAndSettle();
      api.gate = Completer<RouterSnapshot>();
      await tester.tap(find.text(page).last);
      await tester.pump();
      expect(find.text('正在核对数据 · 下方是上次成功读取的状态'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await api.release();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final page in ['总览', '设备', 'Wi-Fi', '流量']) {
    testWidgets(
      'iOS $page uses native pull refresh and completes the gesture',
      (tester) async {
        final api = _PullRefreshApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: const EdgeInsets.only(top: 60)),
              child: child!,
            ),
            home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
          ),
        );
        await tester.pumpAndSettle();
        if (page != '总览') {
          await tester.tap(find.text(page).last);
          await tester.pumpAndSettle();
        }
        expect(
          find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(RefreshIndicator), findsNothing);
        final scroll = find.byKey(const ValueKey('router-page-scroll'));
        expect(
          tester.widget<CustomScrollView>(scroll).physics,
          isA<BouncingScrollPhysics>(),
        );
        final before = api.sections
            .where((section) => section != RouterSection.live)
            .length;
        api.gate = Completer<RouterSnapshot>();
        await tester.timedDrag(
          scroll,
          const Offset(0, 400),
          const Duration(milliseconds: 500),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          api.sections.where((section) => section != RouterSection.live).length,
          before + 1,
        );
        final indicator = find.descendant(
          of: find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
          matching: find.byType(CupertinoActivityIndicator),
        );
        expect(indicator, findsOneWidget);
        for (var frame = 0; frame < 20; frame++) {
          if (CupertinoSliverRefreshControl.state(tester.element(indicator)) ==
              RefreshIndicatorMode.refresh) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          CupertinoSliverRefreshControl.state(tester.element(indicator)),
          RefreshIndicatorMode.refresh,
        );
        expect(tester.getCenter(indicator).dy, greaterThan(60));
        await api.release();
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(position.pixels, closeTo(0, 0.1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('iOS settings keeps a 44 point target with a smaller gear', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _HealthyApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gear = find.byIcon(CupertinoIcons.gear);
    final button = find.ancestor(
      of: gear,
      matching: find.byType(CupertinoButton),
    );
    expect(tester.getSize(button), const Size(44, 44));
    expect(tester.widget<Icon>(gear).size, 20);
    await tester.tapAt(tester.getTopLeft(button) + const Offset(2, 22));
    await tester.pumpAndSettle();
    expect(find.text('连接路由器'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'iOS sheets move smoothly and respect reduced motion=$reducedMotion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
            home: RouterHome(
              storage: _MemoryStorage(),
              apiFactory: (_) => _HealthyApi(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(CupertinoIcons.gear));
        await tester.pump();
        final route = ModalRoute.of(tester.element(find.text('连接路由器')))!;
        expect(
          route.transitionDuration,
          reducedMotion ? Duration.zero : const Duration(milliseconds: 400),
        );
        expect(
          route.reverseTransitionDuration,
          reducedMotion ? Duration.zero : const Duration(milliseconds: 300),
        );
        expect(route.barrierColor?.a ?? 0, 0);
        if (!reducedMotion) {
          final start = tester.getTopLeft(find.byType(BottomSheet)).dy;
          await tester.pump(const Duration(milliseconds: 100));
          final early = tester.getTopLeft(find.byType(BottomSheet)).dy;
          await tester.pump(const Duration(milliseconds: 100));
          final middle = tester.getTopLeft(find.byType(BottomSheet)).dy;
          await tester.pumpAndSettle();
          final end = tester.getTopLeft(find.byType(BottomSheet)).dy;
          expect(start, greaterThan(early));
          expect(early, greaterThan(middle));
          expect(middle, greaterThan(end));
          // Grab the settled sheet, then release a short downward drag.
          final drag = await tester.startGesture(
            tester.getTopLeft(find.byType(BottomSheet)) + const Offset(120, 25),
          );
          await drag.moveBy(const Offset(0, 35));
          await tester.pump();
          await drag.up();
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
        } else {
          await tester.pumpAndSettle();
        }
        await tester.tapAt(const Offset(8, 80));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        '$platform modal glass preserves page appearance in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform, brightness: brightness),
              home: RouterHome(
                storage: _MemoryStorage(),
                apiFactory: (_) => _DeviceIdentityApi(dualStack: true),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byIcon(
              platform == TargetPlatform.iOS
                  ? CupertinoIcons.gear
                  : Icons.settings_outlined,
            ),
          );
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          if (platform == TargetPlatform.android) {
            final glass = find.descendant(
              of: sheet,
              matching: find.byType(BackdropFilter),
            );
            expect(glass, findsOneWidget);
            final surface = tester.widget<DecoratedBox>(
              find
                  .descendant(of: glass, matching: find.byType(DecoratedBox))
                  .first,
            );
            expect(
              (surface.decoration as BoxDecoration).color!.a,
              lessThan(0.2),
            );
          } else {
            final route = ModalRoute.of(tester.element(find.text('连接路由器')))!;
            expect(route.barrierColor?.a ?? 0, 0);
          }
          await tester.tapAt(const Offset(8, 80));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          if (platform == TargetPlatform.iOS) {
            await tester.tap(find.byKey(const ValueKey('topology-devices')));
            await tester.pumpAndSettle();
            final tile = find.byKey(const ValueKey('device-192.168.2.114'));
            await tester.ensureVisible(tile);
            await tester.tap(tile);
            await tester.pumpAndSettle();
            final route = ModalRoute.of(
              tester.element(find.byKey(const ValueKey('device-detail-close'))),
            )!;
            expect(route.barrierColor?.a ?? 0, 0);
            await tester.tapAt(const Offset(8, 80));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'Android device sheet uses transparent page glass in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
              brightness: brightness,
            ),
            home: RouterHome(
              storage: _MemoryStorage(),
              apiFactory: (_) => _DeviceIdentityApi(dualStack: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('topology-devices')));
        await tester.pumpAndSettle();
        expect(find.text('DHCP 2 · 流量记录 1'), findsOneWidget);
        final tile = find.byKey(const ValueKey('device-192.168.2.114'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        final glass = find.descendant(
          of: sheet,
          matching: find.byType(BackdropFilter),
        );
        expect(glass, findsOneWidget);
        final surface = tester.widget<DecoratedBox>(
          find.descendant(of: glass, matching: find.byType(DecoratedBox)).first,
        );
        final color = (surface.decoration as BoxDecoration).color!;
        expect(color.a, lessThan(0.2));
        expect(find.text('300 B'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('device-detail-close')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'Android navigation matches status glass in $brightness motion=$reducedMotion',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 34);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: TargetPlatform.android,
                brightness: brightness,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reducedMotion),
                child: child!,
              ),
              home: RouterHome(
                storage: _MemoryStorage(),
                apiFactory: (_) => _HealthyApi(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final navigation = find.byKey(
            const ValueKey('android-navigation-glass'),
          );
          final status = find.byKey(const ValueKey('system-status-glass'));
          Color tint(Finder root) =>
              (tester
                          .widget<DecoratedBox>(
                            find
                                .descendant(
                                  of: root,
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .color!;
          final navFilter = tester.widget<BackdropFilter>(
            find.descendant(
              of: navigation,
              matching: find.byType(BackdropFilter),
            ),
          );
          final statusFilter = tester.widget<BackdropFilter>(
            find
                .descendant(of: status, matching: find.byType(BackdropFilter))
                .first,
          );
          expect(
            tint(navigation).withValues(alpha: 1),
            tint(status).withValues(alpha: 1),
          );
          expect(tint(status).a, lessThan(tint(navigation).a));
          expect(tint(navigation).a, lessThan(0.2));
          expect(navFilter.filter, statusFilter.filter);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('dual stack device addresses wrap and copy on $platform', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform, brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _DeviceIdentityApi(dualStack: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topology-devices')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('device-240e:1234:5678:9abc:1111:2222:3333:4444'),
        ),
        findsNothing,
      );
      final tile = find.byKey(const ValueKey('device-192.168.2.114'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('300 B'), findsWidgets);
      final copy = find.byKey(
        const ValueKey('copy-address-240e:1234:5678:9abc:1111:2222:3333:4444'),
      );
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, '240e:1234:5678:9abc:1111:2222:3333:4444');
      expect(
        find.text('240e:1234:5678:9abc:1111:2222:3333:4444'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'device sheet scrolls with large text and full IPv6 on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _DeviceIdentityApi(longValues: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('compact-navigation')),
          matching: find.text('设备'),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.byKey(
        const ValueKey('device-fdc8:64ed:f962:0000:0000:0000:0000:0d1c'),
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.text('fdc8:64ed:f962:0000:0000:0000:0000:0d1c'),
        findsOneWidget,
      );
      expect(find.text('根据设备名称推断'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('device-evidence-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('device-evidence-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('根据设备名称推断'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets('device brand and detail work on $platform $brightness', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform, brightness: brightness),
            home: RouterHome(
              storage: _MemoryStorage(),
              apiFactory: (_) => _DeviceIdentityApi(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('topology-devices')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('device-brand-apple')),
          findsOneWidget,
        );
        expect(find.text('未命名设备'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('device-192.168.2.114')));
        await tester.pumpAndSettle();
        expect(find.text('本次会话流量'), findsOneWidget);
        expect(find.text('02:11:22:33:44:55'), findsOneWidget);
        expect(find.text('根据设备名称推断'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('device-evidence-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('根据设备名称推断'), findsOneWidget);
        expect(find.text('DHCP 租约'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('device-evidence-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('根据设备名称推断'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('device-detail-close')));
        await tester.pumpAndSettle();
        expect(find.text('本次会话流量'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'Android rechecks native dark mode after returning from background',
    (tester) async {
      const channel = MethodChannel('com.medyma.immortalwrt/appearance');
      var dark = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'getAppearance'
            ? {'dark': dark, 'accent': 0xFF2563EB}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const ImmortalWrtApp());
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      dark = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('capsule hides upward and returns on downward drag anywhere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
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
    final header = find.byKey(const ValueKey('scrolling-toolbar'));
    expect(header.hitTestable(), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(header).color,
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
    );
    final status = find.byKey(const ValueKey('system-status-glass'));
    expect(tester.getRect(status), const Rect.fromLTWH(0, 0, 390, 32));
    final nav = find.byKey(const ValueKey('compact-navigation'));
    final fade = find.ancestor(of: nav, matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    await tester.drag(
      find.byKey(const ValueKey('router-page-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    expect(header.hitTestable(), findsNothing);
    expect(tester.getRect(status), const Rect.fromLTWH(0, 0, 390, 32));
    expect(
      Focus.of(
        tester.element(find.descendant(of: nav, matching: find.text('总览'))),
      ).canRequestFocus,
      isFalse,
    );
    expect(
      find.descendant(of: nav, matching: find.text('总览')).hitTestable(),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const ValueKey('router-page-scroll')),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('router-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    await tester.drag(
      find.byKey(const ValueKey('router-page-scroll')),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    await tester.drag(
      find.byKey(const ValueKey('router-page-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    await tester.tap(find.descendant(of: nav, matching: find.text('总览')));
    await tester.pump();
    expect(find.text('MT7988 状态'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final (accessible, touchExploration) in [
    (false, null),
    (true, null),
    (true, false),
    (true, true),
  ]) {
    testWidgets(
      'Android capsule accessibility $accessible touch exploration $touchExploration',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const accessibility = MethodChannel(
          'com.medyma.immortalwrt/navigation-accessibility',
        );
        if (touchExploration != null) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            accessibility,
            (_) async => touchExploration,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(accessibility, null),
          );
        }
        final keepVisible = touchExploration ?? accessible;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(accessibleNavigation: accessible),
              child: child!,
            ),
            theme: ThemeData(platform: TargetPlatform.android),
            home: RouterHome(
              storage: _MemoryStorage(),
              apiFactory: (_) => _FakeRouterApi(),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('设备').last);
        await tester.pump();
        final list = find.byKey(const ValueKey('router-page-scroll'));
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, 0);
        final nav = find.byKey(const ValueKey('compact-navigation'));
        final fade = find.ancestor(
          of: nav,
          matching: find.byType(AnimatedOpacity),
        );
        await tester.drag(list, const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedOpacity>(fade).opacity,
          keepVisible ? 1 : 0,
        );
        await tester.drag(list, const Offset(0, 150));
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
        await tester.tap(find.descendant(of: nav, matching: find.text('总览')));
        await tester.pump();
        final overviewPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('router-page-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        overviewPosition.jumpTo(overviewPosition.maxScrollExtent);
        await tester.pump();
        expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
        await tester.drag(
          find.byKey(const ValueKey('router-page-scroll')),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedOpacity>(fade).opacity,
          keepVisible ? 1 : 0,
        );
        if (touchExploration == false) {
          for (final enabled in [true, false]) {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              accessibility.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('touchExplorationChanged', enabled),
              ),
              (_) {},
            );
            await tester.pumpAndSettle();
            expect(
              tester.widget<AnimatedOpacity>(fade).opacity,
              enabled ? 1 : 0,
            );
          }
        }
        if (keepVisible) {
          final destination = find.descendant(
            of: nav,
            matching: find.text('设备'),
          );
          expect(destination.hitTestable(), findsOneWidget);
          expect(Focus.of(tester.element(destination)).canRequestFocus, isTrue);
          expect(
            tester.getSemantics(destination).getSemanticsData().label,
            '设备',
          );
          await tester.tap(destination);
          await tester.pump();
          expect(find.text('设备记录'), findsOneWidget);
        }
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'one-second live updates preserve static chrome and hardware widgets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ChangingLiveApi();
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(storage: _MemoryStorage(), apiFactory: (_) => api),
        ),
      );
      await tester.pump();
      final nav = tester.widget(
        find.byKey(const ValueKey('compact-navigation')),
      );
      final status = tester.widget(
        find.byKey(const ValueKey('system-status-glass')),
      );
      final hardware = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_PpeCard'),
      );
      expect(find.text('1.0 KiB/s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(api.sections.last, RouterSection.live);
      expect(find.text('2.0 KiB/s'), findsOneWidget);
      expect(
        identical(
          nav,
          tester.widget(find.byKey(const ValueKey('compact-navigation'))),
        ),
        isTrue,
      );
      expect(
        identical(
          status,
          tester.widget(find.byKey(const ValueKey('system-status-glass'))),
        ),
        isTrue,
      );
      expect(
        identical(
          hardware,
          tester.widget(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_PpeCard',
            ),
          ),
        ),
        isTrue,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('compact-navigation'))).height,
        52,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('iOS connection actions use Cupertino host fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _FakeRouterApi(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.gear));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CupertinoButton, '连接'), findsOneWidget);
    expect(find.widgetWithText(CupertinoButton, '退出并清除凭据'), findsOneWidget);
    final connectRect = tester.getRect(
      find.widgetWithText(CupertinoButton, '连接'),
    );
    final disconnectRect = tester.getRect(
      find.widgetWithText(CupertinoButton, '退出并清除凭据'),
    );
    expect(disconnectRect.top - connectRect.bottom, greaterThanOrEqualTo(20));
    expect(find.byType(TextButton), findsNothing);
    await tester.tap(find.widgetWithText(CupertinoButton, '退出并清除凭据'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CupertinoButton, '连接路由器'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoButton, '连接路由器'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('appearance follows live system brightness without restarting', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ImmortalWrtApp());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
  testWidgets('accessible chrome avoids blur and remains navigable', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          highContrast: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: RouterHome(
          storage: _MemoryStorage(),
          apiFactory: (_) => _FakeRouterApi(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Wi-Fi'),
      ),
    );
    await tester.pump();
    expect(find.text('BE14 无线'), findsOneWidget);
    await tester.tap(find.byTooltip('连接设置'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'glass connection sheet keeps connect reachable with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _FakeRouterApi(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('连接设置'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '连接'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, '连接').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('connection labels keep original copy and clear field spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RouterHome(storage: _MemoryStorage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('连接设置'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    const labels = ['远程 HTTPS / 本地 HTTP（明文）', '用户名', '密码'];
    for (var i = 0; i < labels.length; i++) {
      final label = find.text(labels[i]);
      expect(label, findsOneWidget);
      expect(
        tester.getRect(fields.at(i)).top - tester.getRect(label).bottom,
        greaterThanOrEqualTo(8),
      );
      expect(tester.getSize(fields.at(i)).height, greaterThanOrEqualTo(56));
      expect(
        tester.getSemantics(fields.at(i)).getSemanticsData().label,
        contains(labels[i]),
      );
    }
    expect(
      tester.widget<TextField>(fields.first).decoration!.hintText,
      'https://bananapi.x.ddnsto.com',
    );
    expect(find.text('路由器地址'), findsNothing);
    expect(find.text('输入路由器密码'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
  testWidgets(
    'overview counts merged traffic devices and excludes lease-only rows',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _DeviceIdentityApi(dualStack: true),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('有流量记录的设备'), 350);
      final row = find
          .ancestor(of: find.text('有流量记录的设备'), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: row, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tiny positive PPE usage is visible but keeps precise actual percentage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _PpeApi(
              tables: const [
                PpeTable(index: 0, bound: 0, capacity: 32768),
                PpeTable(index: 1, bound: 2, capacity: 32768),
                PpeTable(index: 2, bound: 32768, capacity: 32768),
                PpeTable(index: 3, bound: 2),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('PPE 2'), 200);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars, hasLength(3));
      expect(bars[0].value, 0);
      expect(bars[0].semanticsValue, '0.0000%');
      expect(find.text('0.0000%'), findsOneWidget);
      final width = tester
          .getSize(find.byType(LinearProgressIndicator).at(1))
          .width;
      expect(bars[1].value! * width, closeTo(2, 0.001));
      expect(bars[1].semanticsValue, '0.0061%');
      expect(find.text('0.0061%'), findsOneWidget);
      expect(bars[2].value, 1);
      expect(bars[2].semanticsValue, '100.0000%');
      expect(find.text('100.0000%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 430.0]) {
    testWidgets('PPE percentage columns stay aligned at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _PpeApi(
              tables: const [
                PpeTable(index: 0, bound: 0, capacity: 1000000),
                PpeTable(index: 1, bound: 204993, capacity: 1000000),
                PpeTable(index: 2, bound: 1000000, capacity: 1000000),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // Isolate the card from unrelated overview widgets on narrow screens.
      final card = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_PpeCard',
        ),
      );
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(18), child: card),
          ),
        ),
      );
      await tester.pump();
      final count = tester.getRect(find.text('204993 / 1000000'));
      final percentage = tester.getRect(find.text('20.4993%'));
      expect(percentage.left - count.right, closeTo(8, 0.01));
      final labels = ['0.0000%', '20.4993%', '100.0000%'];
      final first = tester.getRect(find.text(labels.first));
      final longest = tester.renderObject<RenderParagraph>(
        find.text('100.0000%'),
      );
      expect(
        first.width,
        closeTo(
          longest.getMaxIntrinsicWidth(double.infinity).ceilToDouble(),
          0.01,
        ),
      );
      for (final label in labels) {
        final finder = find.text(label);
        final rect = tester.getRect(finder);
        expect(rect.right, closeTo(first.right, 0.01));
        expect(rect.width, closeTo(first.width, 0.01));
        final text = tester.widget<Text>(finder);
        expect(text.textAlign, TextAlign.right);
        expect(text.style?.fontSize, 12);
        expect(text.style?.fontWeight, FontWeight.w600);
        expect(text.style?.fontFeatures?.single.feature, 'tnum');
      }
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars[1].value, closeTo(0.204993, 0.0000001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
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
    expect(find.text('12.5000%'), findsOneWidget);
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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final reducedMotion in [false, true]) {
        testWidgets(
          '$platform scrolled blue content remains visible through status blur in $brightness motion=$reducedMotion',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.viewPadding = const FakeViewPadding(
              top: 64,
              bottom: 34,
            );
            addTearDown(tester.view.reset);
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  theme: ThemeData(platform: platform, brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reducedMotion),
                    child: child!,
                  ),
                  home: RouterHome(
                    storage: _MemoryStorage(),
                    apiFactory: (_) => _HealthyApi(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.text('1.0 KiB/s'));
            final scroll = tester.state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('router-page-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            scroll.position.jumpTo(rect.center.dy - 32);
            await tester.pumpAndSettle();
            final status = find.byKey(const ValueKey('system-status-glass'));
            expect(
              find.descendant(
                of: status,
                matching: find.byType(BackdropFilter),
              ),
              findsAtLeastNWidgets(2),
            );
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final bytes = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                return await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
              } finally {
                image.dispose();
              }
            });
            var blueContrast = 0;
            for (var y = 12; y < 52; y++) {
              for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
                final offset = (y * 390 + x) * 4;
                final contrast =
                    bytes!.getUint8(offset + 2) - bytes.getUint8(offset);
                if (contrast > blueContrast) blueContrast = contrast;
              }
            }
            expect(
              blueContrast,
              greaterThan(30),
              reason:
                  'Status glass must reveal blurred blue content even with Reduce Motion enabled',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
      testWidgets('$platform status blur shares page hue in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform, brightness: brightness),
            home: RouterHome(
              storage: _MemoryStorage(),
              apiFactory: (_) => _HealthyApi(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final status = find.byKey(const ValueKey('system-status-glass'));
        expect(tester.getRect(status), const Rect.fromLTWH(0, 0, 390, 32));
        expect(
          find.descendant(of: status, matching: find.byType(BackdropFilter)),
          findsAtLeastNWidgets(2),
        );
        final surface = tester.widget<DecoratedBox>(
          find
              .descendant(of: status, matching: find.byType(DecoratedBox))
              .first,
        );
        final tint = (surface.decoration as BoxDecoration).color!;
        final page = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(tint.withValues(alpha: 1), page.backgroundColor);
        expect(page.extendBody, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'iOS extends behind chrome and hides on up drag, restores on down drag',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: RouterHome(
            storage: _MemoryStorage(),
            apiFactory: (_) => _HealthyApi(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
        isTrue,
      );
      final nav = find.byKey(const ValueKey('ios-navigation-shell'));
      final fade = find.descendant(
        of: nav,
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
      await tester.drag(
        find.byKey(const ValueKey('router-page-scroll')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
      expect(find.byType(CupertinoTabBar).hitTestable(), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('router-page-scroll')),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
      expect(find.byType(CupertinoTabBar).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      return {'dark': false, 'accent': 0xFFBF5AF2};
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
