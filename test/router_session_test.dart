import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/services/router_api.dart';
import 'package:immortalwrt_app/services/router_session.dart';

void main() {
  test(
    'mixed missing methods and ACL denial remain scoped without relogin',
    () async {
      var logins = 0;
      final methods = <String>[];
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
          final p = (jsonDecode(request.body) as Map)['params'] as List;
          if (p[2] == 'login') {
            logins++;
            return http.Response(
              '{"result":[0,{"ubus_rpc_session":"s"}]}',
              200,
            );
          }
          methods.add(p[2] as String);
          return http.Response(
            p[2] == 'getWirelessStatus' ? '{"result":[6]}' : '{"result":[4]}',
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final session = RouterSession(
        api,
        () async => const RouterCredentials('u', 'p'),
      );
      final snapshot = await session.fetch(RouterSection.wifi);
      expect(logins, 1);
      expect(methods, ['getWirelessStatus', 'getWirelessHistory']);
      expect(snapshot.wifiError, contains('权限'));
      expect(snapshot.wifiHistoryError, isNotNull);
      api.close();
    },
  );
  for (final timeout in [60, 300, 0]) {
    test('idle recovery respects server timeout $timeout', () async {
      var now = DateTime(2026, 10, 2);
      var logins = 0;
      final tokens = <String>[];
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
                  {'ubus_rpc_session': 's$logins', 'timeout': timeout},
                ],
              }),
              200,
            );
          }
          tokens.add(p[0] as String);
          return http.Response('{"result":[0,{}]}', 200);
        }),
      );
      await api.login('u', 'p');
      final session = RouterSession(
        api,
        () async => const RouterCredentials('u', 'p'),
      );
      now = now.add(const Duration(minutes: 22));
      await session.fetch(RouterSection.live);
      expect(logins, timeout == 0 ? 1 : 2);
      expect(tokens, [timeout == 0 ? 's1' : 's2']);
      api.close();
    });
  }

  test(
    'successful reads renew idle timeout and partial ACL remains an error',
    () async {
      var now = DateTime(2026, 10, 2);
      var logins = 0;
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        clock: () => now,
        client: MockClient((request) async {
          final p = (jsonDecode(request.body) as Map)['params'] as List;
          if (p[2] == 'login') {
            logins++;
            return http.Response(
              '{"result":[0,{"ubus_rpc_session":"s","timeout":60}]}',
              200,
            );
          }
          return http.Response(
            p[2] == 'getSummary' ? '{"result":[6]}' : '{"result":[0,{}]}',
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final session = RouterSession(
        api,
        () async => const RouterCredentials('u', 'p'),
      );
      now = now.add(const Duration(seconds: 50));
      await session.fetch(RouterSection.live);
      now = now.add(const Duration(seconds: 50));
      final snapshot = await session.fetch(RouterSection.devices);
      expect(logins, 1);
      expect(snapshot.trafficError, contains('权限'));
      expect(snapshot.devicesError, isNull);
      api.close();
    },
  );

  test('expired session logs in once and retries the visible page', () async {
    var logins = 0;
    var reads = 0;
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
          logins++;
          return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 's$logins'},
              ],
            }),
            200,
          );
        }
        reads++;
        return http.Response(
          jsonEncode({
            'result': [logins == 1 ? 6 : 0, {}],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final session = RouterSession(
      api,
      () async => const RouterCredentials('u', 'p'),
    );
    final snapshot = await session.fetch(RouterSection.wifi);
    expect(snapshot.radios, isEmpty);
    expect(logins, 2);
    expect(reads, 5);
  });

  test('still denied after one re-login reports ACL failure', () async {
    var logins = 0;
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
          logins++;
          return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 's'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': [6],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final session = RouterSession(
      api,
      () async => const RouterCredentials('u', 'p'),
    );
    await expectLater(
      session.fetch(RouterSection.wifi),
      throwsA(predicate((error) => '$error'.contains('ACL'))),
    );
    expect(logins, 2);
  });
  test(
    'idle session renews before reads despite missing modules and transient failures',
    () async {
      var now = DateTime(2026, 10, 2);
      var logins = 0;
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
                  {'ubus_rpc_session': 's$logins'},
                ],
              }),
              200,
            );
          }
          if (p[1] == 'luci.sfp-status') {
            return http.Response('{"result":[4]}', 200);
          }
          if (p[2] == 'getWirelessStatus') {
            return http.Response('temporary failure', 503);
          }
          return http.Response(
            jsonEncode({
              'result': [logins == 1 ? 6 : 0, {}],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      now = now.add(const Duration(minutes: 22));
      final session = RouterSession(
        api,
        () async => const RouterCredentials('u', 'p'),
      );
      final snapshot = await session.fetch(RouterSection.overview);
      expect(logins, 2);
      expect(snapshot.trafficError, isNull);
      expect(snapshot.sfpError, isNotNull);
      expect(snapshot.wifiError, contains('503'));
      api.close();
    },
  );
}
