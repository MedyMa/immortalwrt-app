import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/services/router_api.dart';
import 'package:immortalwrt_app/services/router_session.dart';

void main() {
  test('expired session logs in once and retries the visible page', () async {
    var logins = 0;
    var reads = 0;
    final api = RouterApi(Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
      final params = (jsonDecode(request.body) as Map)['params'] as List;
      if (params[2] == 'login') {
        logins++;
        return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 's$logins'}
              ]
            }),
            200);
      }
      reads++;
      return http.Response(
          jsonEncode({
            'result': [logins == 1 ? 6 : 0, {}]
          }),
          200);
    }));
    await api.login('u', 'p');
    final session =
        RouterSession(api, () async => const RouterCredentials('u', 'p'));
    final snapshot = await session.fetch(RouterSection.wifi);
    expect(snapshot.radios, isEmpty);
    expect(logins, 2);
    expect(reads, 2);
  });

  test('still denied after one re-login reports ACL failure', () async {
    var logins = 0;
    final api = RouterApi(Uri.parse('https://router.example.com'),
        client: MockClient((request) async {
      final params = (jsonDecode(request.body) as Map)['params'] as List;
      if (params[2] == 'login') {
        logins++;
        return http.Response(
            jsonEncode({
              'result': [
                0,
                {'ubus_rpc_session': 's'}
              ]
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'result': [6]
          }),
          200);
    }));
    await api.login('u', 'p');
    final session =
        RouterSession(api, () async => const RouterCredentials('u', 'p'));
    await expectLater(session.fetch(RouterSection.wifi),
        throwsA(predicate((error) => '$error'.contains('ACL'))));
    expect(logins, 2);
  });
}
