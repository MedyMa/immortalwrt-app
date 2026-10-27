import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immortalwrt_app/models/router_models.dart';
import 'package:immortalwrt_app/services/router_api.dart';

Map<String, Object?> statusData() => {
  'schema': 3,
  'npu': {
    'status_node_present': true,
    'firmware_ready': true,
    'mcu_alive': true,
    'registered_tunnel_types': 3,
    'coverage': 'complete',
    'packet_offload_verified': false,
  },
  'tunnels': {
    'coverage': 'complete',
    'capacity': 32,
    'count': 0,
    'entries': [],
  },
};

void main() {
  test('readiness does not prove hardware forwarding', () {
    final status = NpuStatus.tryParse(statusData())!;
    expect(status.ready, true);
    expect(status.packetForwardingVerified, false);
  });
  test('unknown schema and non-boolean state are rejected', () {
    expect(NpuStatus.tryParse({...statusData(), 'schema': 4}), isNull);
    expect(NpuStatus.tryParse({'available': false}), isNull);
    expect(NpuStatus.tryParse({...statusData(), 'schema': 2})!.ready, true);
    final data = statusData();
    data['npu'] = {...(data['npu'] as Map), 'firmware_ready': 'true'};
    expect(NpuStatus.tryParse(data), isNull);
  });
  test('incomplete or absent driver is never reported active', () {
    for (final state in [
      {'coverage': 'truncated'},
      {'status_node_present': false},
      {'mcu_alive': false},
      {'firmware_ready': false},
    ]) {
      final data = statusData();
      data['npu'] = {
        ...(data['npu'] as Map),
        ...state,
        'packet_offload_verified': true,
      };
      final status = NpuStatus.tryParse(data)!;
      expect(status.ready, false);
      expect(status.packetForwardingVerified, false);
    }
  });
  test(
    'NPU reads use router.status, throttle and stay separate from live rates',
    () async {
      var now = DateTime(2026, 10, 27);
      final methods = <String>[];
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        clock: () => now,
        client: MockClient((r) async {
          final params = (jsonDecode(r.body) as Map)['params'] as List;
          methods.add('${params[1]}.${params[2]}');
          final data = params[2] == 'login'
              ? {'ubus_rpc_session': 'token', 'timeout': 0}
              : params[2] == 'getNpuStatus'
              ? statusData()
              : <String, Object?>{};
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
      expect(first.npu!.ready, true);
      expect(methods.where((s) => s.endsWith('.getNpuStatus')), [
        'router.status.getNpuStatus',
      ]);
      methods.clear();
      now = now.add(const Duration(seconds: 5));
      final second = await api.fetch(
        section: RouterSection.overview,
        previous: first,
      );
      expect(methods.any((s) => s.endsWith('.getNpuStatus')), false);
      expect(second.npu, same(first.npu));
      methods.clear();
      await api.fetch(section: RouterSection.live, previous: second);
      expect(methods, ['luci.traffic.getLive']);
      methods.clear();
      now = now.add(const Duration(seconds: 30));
      await api.fetch(section: RouterSection.overview, previous: second);
      expect(methods.where((s) => s.endsWith('.getNpuStatus')).length, 1);
      api.close();
    },
  );
  test(
    'missing optional method or helper never disables other overview data',
    () async {
      for (final missingMethod in [true, false]) {
        final api = RouterApi(
          Uri.parse('http://192.168.2.1'),
          client: MockClient((r) async {
            final p = (jsonDecode(r.body) as Map)['params'] as List;
            if (p[2] == 'getNpuStatus' && missingMethod) {
              return http.Response('{"result":[4]}', 200);
            }
            final data = p[2] == 'login'
                ? {'ubus_rpc_session': 'token'}
                : p[2] == 'getNpuStatus'
                ? {'available': false, 'coverage': 'provider_missing'}
                : p[2] == 'info'
                ? {'uptime': 123}
                : <String, Object?>{};
            return http.Response(
              jsonEncode({
                'result': [0, data],
              }),
              200,
            );
          }),
        );
        await api.login('u', 'p');
        final snapshot = await api.fetch(section: RouterSection.overview);
        expect(snapshot.uptimeSeconds, 123);
        expect(snapshot.npu, isNull);
        expect(snapshot.npuError, isNotNull);
        api.close();
      }
    },
  );
  test(
    'failed refresh retains a stale snapshot without claiming a new observation',
    () async {
      final old = NpuStatus.tryParse(statusData())!;
      final lastRead = DateTime(2026, 10, 26);
      final api = RouterApi(
        Uri.parse('http://192.168.2.1'),
        client: MockClient((r) async {
          final p = (jsonDecode(r.body) as Map)['params'] as List;
          if (p[2] == 'getNpuStatus') {
            return http.Response('{"result":[6]}', 200);
          }
          return http.Response(
            jsonEncode({
              'result': [
                0,
                p[2] == 'login' ? {'ubus_rpc_session': 'token'} : {},
              ],
            }),
            200,
          );
        }),
      );
      await api.login('u', 'p');
      final snapshot = await api.fetch(
        section: RouterSection.overview,
        previous: RouterSnapshot(
          fetchedAt: lastRead,
          npu: old,
          npuFetchedAt: lastRead,
        ),
      );
      expect(snapshot.npu, same(old));
      expect(snapshot.npuError, isNotNull);
      expect(snapshot.npuFetchedAt, lastRead);
      expect(snapshot.npuAttemptedAt, isNotNull);
      api.close();
    },
  );
}
