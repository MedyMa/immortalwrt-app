import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

void main() {
  test(
    'overview reads turboacc PPE only on full refresh and scopes its errors',
    () async {
      final methods = <String>[];
      var deny = false;
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
          final p = (jsonDecode(request.body) as Map)['params'] as List;
          methods.add('${p[1]}.${p[2]}');
          if (p[2] == 'login') {
            return http.Response(
              '{"result":[0,{"ubus_rpc_session":"s"}]}',
              200,
            );
          }
          if (p[1] == 'luci.turboacc') {
            return http.Response(
              deny
                  ? '{"result":[6]}'
                  : '{"result":[0,{"PPE_NUM":"2","BIND_PPE0":"1024","ALL_PPE0":"8192","BIND_PPE1":"0","ALL_PPE1":"8192"}]}',
              200,
            );
          }
          return http.Response('{"result":[0,{}]}', 200);
        }),
      );
      await api.login('u', 'p');
      final first = await api.fetch(section: RouterSection.overview);
      expect(methods, contains('luci.turboacc.getMTKPPEStat'));
      expect(first.ppeTables.first.usedPercent, 12.5);
      expect(first.ppeTables.last.usedPercent, 0);
      methods.clear();
      final live = await api.fetch(
        section: RouterSection.live,
        previous: first,
      );
      expect(live.ppeTables.first.bound, 1024);
      expect(methods, ['luci.traffic.getLive']);
      deny = true;
      final denied = await api.fetch(
        section: RouterSection.overview,
        previous: first,
      );
      expect(denied.trafficError, isNull);
      expect(denied.ppeError, contains('权限'));
      expect(denied.ppeTables.first.bound, 1024);
      api.close();
    },
  );
  test('ubus login then read-only methods use the returned session', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final params = body['params'] as List<dynamic>;
      methods.add('${params[1]}.${params[2]}');
      if (params[2] == 'login') {
        expect(params[0], '00000000000000000000000000000000');
        return http.Response(
          jsonEncode({
            'result': [
              0,
              {'ubus_rpc_session': 'session-token'},
            ],
          }),
          200,
        );
      }
      expect(params[0], 'session-token');
      if (params[2] == 'getSummary') {
        return http.Response(
          jsonEncode({
            'result': [
              0,
              {
                'totals': {'down': 42, 'up': 8},
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'result': [0, {}],
        }),
        200,
      );
    });
    final api = RouterApi(Uri.parse('http://192.168.2.1'), client: client);
    await api.login('mobile', 'secret');
    final snapshot = await api.fetch();
    expect(snapshot.summary?.headlineDown, 42);
    expect(
      methods,
      containsAll([
        'session.login',
        'luci.traffic.getSummary',
        'luci.traffic.getLive',
        'luci.traffic.getSeries',
        'router.status.getWirelessStatus',
        'system.info',
      ]),
    );
    expect(methods, isNot(contains('luci.traffic.resetStats')));
  });

  test('missing Wi-Fi ubus method does not discard traffic data', () async {
    final api = RouterApi(
      Uri.parse('http://192.168.2.1'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
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
        if (params[2] == 'getWirelessStatus') {
          return http.Response(
            jsonEncode({
              'result': [4],
            }),
            200,
          );
        }
        if (params[2] == 'getSummary') {
          return http.Response(
            jsonEncode({
              'result': [
                0,
                {
                  'totals': {'down': 8, 'up': 1},
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': [0, {}],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final snapshot = await api.fetch();
    expect(snapshot.summary?.headlineDown, 8);
    expect(snapshot.wifiError, isNotNull);
  });

  test('HTTP is limited to private local endpoints', () {
    expect(
      () => RouterApi.validateUrl('http://example.com'),
      throwsFormatException,
    );
    expect(
      () => RouterApi.validateUrl('http://192.168.2.2'),
      throwsFormatException,
    );
    expect(() => RouterApi.validateUrl('http://192.168.2.1'), returnsNormally);
    expect(
      () => RouterApi.validateUrl('https://router.example.com'),
      returnsNormally,
    );
  });

  test('section fetch requests only data needed by visible page', () async {
    final methods = <String>[];
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        methods.add('${params[1]}.${params[2]}');
        if (params[2] == 'login') {
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
            'result': [0, {}],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    await api.fetch(section: RouterSection.wifi);
    expect(methods, [
      'session.login',
      'router.status.getWirelessStatus',
      'router.status.getWirelessHistory',
    ]);
    methods.clear();
    await api.fetch(section: RouterSection.devices);
    expect(
      methods,
      containsAll(['luci.traffic.getSummary', 'luci-rpc.getDHCPLeases']),
    );
    expect(methods, hasLength(2));
  });

  test('expired session is distinguishable from missing method', () async {
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
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
    expect(
      () => api.fetch(section: RouterSection.wifi),
      throwsA(isA<RouterSessionExpiredException>()),
    );
  });

  test('series failure is shown independently of summary', () async {
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
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
        if (params[2] == 'getSeries') {
          return http.Response(
            jsonEncode({
              'result': [4],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': [0, {}],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final snapshot = await api.fetch(section: RouterSection.traffic);
    expect(snapshot.seriesError, contains('getSeries'));
    expect(snapshot.trafficError, isNull);
  });

  test('DNS failure has its own message', () async {
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient(
        (request) async => throw const SocketException('DNS failed'),
      ),
    );
    expect(
      () => api.login('u', 'p'),
      throwsA(predicate((error) => '$error'.contains('DNS'))),
    );
  });

  test('TLS handshake and HTTP rejection have distinct messages', () async {
    final tls = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient(
        (request) async => throw const HandshakeException('bad certificate'),
      ),
    );
    await expectLater(
      tls.login('u', 'p'),
      throwsA(predicate((error) => '$error'.contains('TLS 证书'))),
    );

    final rejected = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async => http.Response('Forbidden', 403)),
    );
    await expectLater(
      rejected.login('u', 'p'),
      throwsA(predicate((error) => '$error'.contains('HTTP 403'))),
    );
  });

  test('failed current section keeps previously successful data', () async {
    var deny = false;
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final params = (jsonDecode(request.body) as Map)['params'] as List;
        if (params[2] == 'login') {
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
        if (params[2] == 'getSeries' && deny) {
          return http.Response(
            jsonEncode({
              'result': [4],
            }),
            200,
          );
        }
        if (params[2] == 'getSeries') {
          return http.Response(
            jsonEncode({
              'result': [
                0,
                {
                  'interval': 10,
                  'points': [
                    [1720000000, 1000, 200],
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': [0, {}],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final first = await api.fetch(section: RouterSection.traffic);
    deny = true;
    final second = await api.fetch(
      section: RouterSection.traffic,
      previous: first,
    );
    expect(second.series?.points.length, 1);
    expect(second.seriesError, isNotNull);
  });

  test(
    'overview reads counters and SFP without fetching traffic series',
    () async {
      final methods = <String>[];
      var metricReads = 0;
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
          final params = (jsonDecode(request.body) as Map)['params'] as List;
          methods.add('${params[1]}.${params[2]}');
          final method = params[2];
          final data = switch (method) {
            'login' => {'ubus_rpc_session': 's'},
            'getSystemMetrics' => {
              'cpu': metricReads++ == 0
                  ? {'total': 100, 'idle': 50}
                  : {'total': 200, 'idle': 80},
            },
            'getStatuses' => {
              'modules': [
                {
                  'interface': 'eth2',
                  'module_slot': 'SFP2',
                  'link_up': true,
                  'speed': '10000Mb/s',
                },
              ],
            },
            'info' => {
              'memory': {'total': 1000, 'available': 300},
            },
            _ => <String, dynamic>{},
          };
          return http.Response(
            jsonEncode({
              'result': [0, data],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final first = await api.fetch(section: RouterSection.overview);
      expect(methods, isNot(contains('luci.traffic.getSeries')));
      expect(first.memory?.usedPercent, 70);
      expect(first.cpuUsagePercent, 70);
      expect(first.sfpPorts.single.speedMbps, 10000);
      final second = await api.fetch(
        section: RouterSection.overview,
        previous: first,
      );
      expect(second.cpuUsagePercent, isNull);
    },
  );

  test(
    'Wi-Fi uses sanitized status and preserves a readable method error',
    () async {
      final methods = <String>[];
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
          final params = (jsonDecode(request.body) as Map)['params'] as List;
          methods.add('${params[1]}.${params[2]}');
          if (params[2] == 'login') {
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
          if (params[2] == 'getWirelessStatus') {
            return http.Response(
              jsonEncode({
                'result': [
                  0,
                  {
                    'radios': [
                      {
                        'name': 'MT7990_2',
                        'up': true,
                        'band': '6g',
                        'channel': 37,
                      },
                    ],
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'error': {'message': 'Unsupported call'},
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final snapshot = await api.fetch(section: RouterSection.wifi);
      expect(methods, [
        'session.login',
        'router.status.getWirelessStatus',
        'router.status.getWirelessHistory',
      ]);
      expect(snapshot.radios.single.band, '6g');
    },
  );

  test(
    'Wi-Fi history is read at most once per minute and retained between polls',
    () async {
      final methods = <String>[];
      final api = RouterApi(
        Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
          final method =
              ((jsonDecode(request.body) as Map)['params'] as List)[2]
                  as String;
          methods.add(method);
          final data = switch (method) {
            'login' => {'ubus_rpc_session': 's'},
            'getWirelessHistory' => {
              'interval': 60,
              'points': [
                [1720000000, 'MT7990_1_2', 100, 200, 6, 16],
              ],
            },
            _ => <String, dynamic>{},
          };
          return http.Response(
            jsonEncode({
              'result': [0, data],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final first = await api.fetch(section: RouterSection.wifi);
      final second = await api.fetch(
        section: RouterSection.wifi,
        previous: first,
      );
      expect(methods.where((item) => item == 'getWirelessHistory').length, 1);
      expect(second.wifiHistory?.points.single.txFailurePercent, 6);
    },
  );

  test('Wi-Fi method failure keeps the router connected', () async {
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final method = ((jsonDecode(request.body) as Map)['params'] as List)[2];
        if (method == 'login') {
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
            'result': [4],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final previous = RouterSnapshot(fetchedAt: DateTime.now());
    final snapshot = await api.fetch(
      section: RouterSection.wifi,
      previous: previous,
    );
    expect(snapshot.wifiError, contains('rpcd-mod-router-status'));
  });

  test('CPU sampling survives a visit to another page', () async {
    var metricReads = 0;
    final api = RouterApi(
      Uri.parse('https://router.example.com'),
      client: MockClient((request) async {
        final method = ((jsonDecode(request.body) as Map)['params'] as List)[2];
        final data = switch (method) {
          'login' => {'ubus_rpc_session': 's'},
          'getSystemMetrics' => {
            'cpu': switch (metricReads++) {
              0 => {'total': 100, 'idle': 50},
              1 => {'total': 200, 'idle': 80},
              _ => {'total': 300, 'idle': 110},
            },
          },
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode({
            'result': [0, data],
          }),
          200,
        );
      }),
    );
    await api.login('u', 'p');
    final first = await api.fetch(section: RouterSection.overview);
    final devices = await api.fetch(
      section: RouterSection.devices,
      previous: first,
    );
    final second = await api.fetch(
      section: RouterSection.overview,
      previous: devices,
    );
    expect(second.cpuUsagePercent, 70);
  });
}
