import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

void main() {
  test(
    'absent status component returns a page error without requiring an old snapshot',
    () async {
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((r) async {
          final p = (jsonDecode(r.body) as Map)['params'] as List;
          return http.Response(
            p[2] == 'login'
                ? '{"result":[0,{"ubus_rpc_session":"token"}]}'
                : '{"error":{"code":-32000,"message":"Object not found"}}',
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final data = await api.fetch(section: RouterSection.wifi);
      expect(data.wifiError, contains('rpcd-mod-router-status'));
      expect(data.radios, isEmpty);
      api.close();
    },
  );
  test(
    'missing traffic leaves hardware status and later live failure scoped',
    () async {
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((r) async {
          final p = (jsonDecode(r.body) as Map)['params'] as List;
          if (p[1] == 'luci.traffic') {
            return http.Response(
              '{"error":{"code":-32000,"message":"Object not found"}}',
              200,
            );
          }
          final data = p[2] == 'login'
              ? {'ubus_rpc_session': 'token'}
              : p[2] == 'getWirelessStatus'
              ? {
                  'radios': [
                    {'name': 'MT7990_1_2', 'up': true, 'band': '5g'},
                  ],
                }
              : <String, dynamic>{};
          return http.Response(
            jsonEncode({
              'result': [0, data],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final overview = await api.fetch(section: RouterSection.overview);
      expect(overview.radios.single.band, '5g');
      expect(overview.liveError, isNotNull);
      final live = await api.fetch(
        section: RouterSection.live,
        previous: overview,
      );
      expect(live.radios.single.band, '5g');
      expect(live.liveError, isNotNull);
      api.close();
    },
  );
  test(
    'Wi-Fi works without traffic installed and calls only router.status',
    () async {
      final objects = <String>[];
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((r) async {
          final p = (jsonDecode(r.body) as Map)['params'] as List;
          objects.add('${p[1]}.${p[2]}');
          Object data = {};
          if (p[2] == 'login') {
            data = {'ubus_rpc_session': 'token'};
          } else if (p[1] == 'luci.traffic') {
            return http.Response(
              '{"error":{"code":-32000,"message":"Object not found"}}',
              200,
            );
          } else if (p[2] == 'getWirelessStatus') {
            data = {
              'radios': [
                {
                  'name': 'MT7990_1_2',
                  'up': true,
                  'band': '5g',
                  'channel': '40',
                  'htmode': 'EHT160',
                },
              ],
            };
          }
          return http.Response(
            jsonEncode({
              'result': [0, data],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final data = await api.fetch(section: RouterSection.wifi);
      expect(data.radios.single.band, '5g');
      expect(objects, [
        'session.login',
        'router.status.getWirelessStatus',
        'router.status.getWirelessHistory',
      ]);
      api.close();
    },
  );
  test(
    'denied wireless ACL checks system session without using traffic',
    () async {
      final objects = <String>[];
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((r) async {
          final p = (jsonDecode(r.body) as Map)['params'] as List;
          objects.add('${p[1]}.${p[2]}');
          if (p[2] == 'login') {
            return http.Response(
              '{"result":[0,{"ubus_rpc_session":"token"}]}',
              200,
            );
          }
          if (p[1] == 'system') {
            return http.Response('{"result":[0,{"uptime":12}]}', 200);
          }
          return http.Response(
            '{"error":{"code":-32002,"message":"Access denied"}}',
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final data = await api.fetch(
        section: RouterSection.wifi,
        previous: RouterSnapshot(fetchedAt: DateTime.now()),
      );
      expect(data.wifiError, contains('权限'));
      expect(objects, contains('system.info'));
      expect(objects.any((o) => o.startsWith('luci.traffic.')), false);
      api.close();
    },
  );
}
