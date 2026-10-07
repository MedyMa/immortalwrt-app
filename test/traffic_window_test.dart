import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

void main() {
  test('24-hour aggregation excludes stale buckets and sorts apps', () {
    final result = TrafficSummary.fromHourly({
      'hours': [
        {
          'hour': '2026-10-01T12',
          'iface': {'down': 900, 'up': 0},
          'apps': [
            {'name': 'Old', 'down': 900},
          ],
        },
        {
          'hour': '2026-10-02T12',
          'iface': {'down': 100, 'up': 20},
          'apps': [
            {'name': 'A', 'down': 40, 'up': 10},
          ],
        },
        {
          'hour': '2026-10-02T13',
          'iface': {'down': 200, 'up': 30},
          'apps': [
            {'name': 'A', 'down': 60},
            {'name': 'B', 'down': 5},
          ],
        },
      ],
    }, now: DateTime(2026, 10, 2, 13, 30));
    expect(result.headlineDown, 300);
    expect(result.headlineUp, 50);
    expect(result.apps.map((a) => a.name), ['A', 'B']);
    expect(result.apps.first.bytes, 110);
  });
  test('partial WAN history is never labelled complete WAN totals', () {
    final result = TrafficSummary.fromHourly({
      'hours': [
        {
          'hour': '2026-10-02T12',
          'iface': {'down': 100, 'up': 20},
          'apps': [
            {'name': 'A', 'down': 40},
          ],
        },
        {
          'hour': '2026-10-02T13',
          'apps': [
            {'name': 'A', 'down': 60},
          ],
        },
      ],
    }, now: DateTime(2026, 10, 2, 13, 30));
    expect(result.hasWanTotals, false);
    expect(result.headlineDown, 100);
  });
  test(
    'Wi-Fi method denial does not imply disconnected valid session',
    () async {
      final calls = <String>[];
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((request) async {
          final params = (jsonDecode(request.body) as Map)['params'] as List;
          final method = params[2] as String;
          calls.add(method);
          if (method == 'login') {
            return http.Response(
              jsonEncode({
                'result': [
                  0,
                  {'ubus_rpc_session': 'token'},
                ],
              }),
              200,
            );
          }
          if (method == 'info') {
            return http.Response('{"result":[0,{}]}', 200);
          }
          return http.Response(
            '{"error":{"code":-32002,"message":"Access denied"}}',
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final snapshot = await api.fetch(
        section: RouterSection.wifi,
        previous: RouterSnapshot(fetchedAt: DateTime.now()),
      );
      expect(snapshot.wifiError, contains('权限'));
      expect(calls.where((m) => m == 'login').length, 1);
      expect(calls, contains('info'));
      api.close();
    },
  );
  test(
    'traffic uses 24-hour archive and live polling reads only rate',
    () async {
      final calls = <List>[];
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((request) async {
          final params = (jsonDecode(request.body) as Map)['params'] as List;
          calls.add(params);
          if (params[2] == 'getHourlyChunk') {
            return http.Response(
              jsonEncode({
                'result': [4],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'result': [
                0,
                params[2] == 'login' ? {'ubus_rpc_session': 'token'} : {},
              ],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      await api.fetch(section: RouterSection.traffic);
      expect(calls.where((p) => p[2] == 'getHourly').single[3], {'hours': 24});
      expect(calls.where((p) => p[2] == 'getSeries').single[3], {
        'range': '24h',
      });
      calls.clear();
      await api.fetch(section: RouterSection.live);
      expect(calls.map((p) => p[2]), ['getLive']);
      api.close();
    },
  );
}
