import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/services/router_api.dart';

void main() {
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
                {'ubus_rpc_session': 'session-token'}
              ]
            }),
            200);
      }
      expect(params[0], 'session-token');
      if (params[2] == 'getSummary') {
        return http.Response(
            jsonEncode({
              'result': [
                0,
                {
                  'totals': {'down': 42, 'up': 8}
                }
              ]
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'result': [0, {}]
          }),
          200);
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
          'network.wireless.status',
          'system.info'
        ]));
    expect(methods, isNot(contains('luci.traffic.resetStats')));
  });

  test('missing Wi-Fi ubus method does not discard traffic data', () async {
    final api = RouterApi(Uri.parse('http://192.168.2.1'),
        client: MockClient((request) async {
      final params = (jsonDecode(request.body) as Map)['params'] as List;
      if (params[2] == 'login') {
        return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 'token'}
              ]
            }),
            200);
      }
      if (params[1] == 'network.wireless') {
        return http.Response(
            jsonEncode({
              'result': [4]
            }),
            200);
      }
      if (params[2] == 'getSummary') {
        return http.Response(
            jsonEncode({
              'result': [
                0,
                {
                  'totals': {'down': 8, 'up': 1}
                }
              ]
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'result': [0, {}]
          }),
          200);
    }));
    await api.login('u', 'p');
    final snapshot = await api.fetch();
    expect(snapshot.summary?.headlineDown, 8);
    expect(snapshot.wifiError, isNotNull);
  });

  test('HTTP is limited to private local endpoints', () {
    expect(() => RouterApi.validateUrl('http://example.com'),
        throwsFormatException);
    expect(() => RouterApi.validateUrl('http://192.168.2.2'),
        throwsFormatException);
    expect(() => RouterApi.validateUrl('http://192.168.2.1'), returnsNormally);
    expect(() => RouterApi.validateUrl('https://router.example.com'),
        returnsNormally);
  });
}
