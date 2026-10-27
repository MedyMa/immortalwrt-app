import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immortalwrt_app/main.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

class _Storage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => {
    'router_url': 'https://router.example.com',
    'router_username': 'test',
    'router_password': 'test',
  }[key];
}

class _NpuApi extends RouterApi {
  _NpuApi(this.stale) : super(Uri.parse('https://router.example.com'));
  final bool stale;
  @override
  Future<void> login(String username, String password) async {}
  @override
  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async => RouterSnapshot(
    fetchedAt: DateTime.now(),
    npu: const NpuStatus(
      present: true,
      readable: true,
      firmwareReady: true,
      mcuAlive: true,
    ),
    npuError: stale ? 'NPU 状态读取失败' : null,
  );
}

void main() {
  for (final dark in [false, true]) {
    for (final stale in [false, true]) {
      testWidgets('NPU status row at narrow width dark=$dark stale=$stale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: RouterHome(
              storage: _Storage(),
              apiFactory: (_) => _NpuApi(stale),
            ),
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(stale ? '状态已过期' : '已就绪 · 待验证'),
          250,
        );
        expect(find.text('NPU 使用状态'), findsOneWidget);
        expect(find.text('已就绪 · 待验证'), stale ? findsNothing : findsOneWidget);
        expect(find.text('收发已验证'), findsNothing);
        expect(find.text('已注册协议'), findsNothing);
        expect(find.text('参数已同步'), findsNothing);
        expect(find.text('暂无隧道记录'), findsNothing);
        expect(find.text('TOPS 隧道'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
