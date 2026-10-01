import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/router_models.dart';

class RouterApiException implements Exception {
  const RouterApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RouterApi {
  RouterApi(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client() {
    validateUrl(baseUrl.toString());
  }

  final Uri baseUrl;
  final http.Client _client;
  String? _session;
  int _nextId = 1;

  static Uri validateUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('请输入路由器根地址，例如 http://192.168.2.1');
    }
    if (uri.scheme == 'http' && uri.host != '192.168.2.1') {
      throw const FormatException('HTTP 首版仅支持 192.168.2.1；其他地址请使用 HTTPS');
    }
    return uri;
  }

  Uri get _endpoint => baseUrl.replace(path: '/ubus');

  Future<Map<String, dynamic>> _call(
      String object, String method, Map<String, dynamic> args,
      {bool login = false}) async {
    final token = login ? '00000000000000000000000000000000' : _session;
    if (token == null) throw const RouterApiException('尚未登录路由器');
    http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': _nextId++,
              'method': 'call',
              'params': [token, object, method, args],
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const RouterApiException('无法连接路由器，请检查 Wi-Fi 和地址');
    }
    if (response.statusCode != 200) {
      throw RouterApiException('路由器返回 HTTP ${response.statusCode}');
    }
    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['result'] is! List) {
        throw const RouterApiException('路由器响应格式不正确');
      }
      final result = payload['result'] as List;
      if (result.isEmpty || result[0] != 0) {
        throw RouterApiException(
            'ubus 拒绝 $object.$method（代码 ${result.isEmpty ? '?' : result[0]}）');
      }
      if (result.length < 2 || result[1] is! Map) return {};
      return (result[1] as Map).map((key, value) => MapEntry('$key', value));
    } on FormatException {
      throw const RouterApiException('路由器返回了无效 JSON');
    }
  }

  Future<void> login(String username, String password) async {
    final result = await _call(
        'session', 'login', {'username': username, 'password': password},
        login: true);
    final session = result['ubus_rpc_session'];
    if (session is! String || session.isEmpty) {
      throw const RouterApiException('登录失败，请检查用户名和密码');
    }
    _session = session;
  }

  Future<RouterSnapshot> fetch() async {
    // A missing plugin or radio must not hide the other sections.
    Future<(Map<String, dynamic>?, String?)> safe(
        String object, String method, Map<String, dynamic> args) async {
      try {
        return (await _call(object, method, args), null);
      } catch (error) {
        return (null, '$error');
      }
    }

    final results = await Future.wait([
      safe('luci.traffic', 'getSummary', {}),
      safe('luci.traffic', 'getLive', {}),
      safe('luci.traffic', 'getSeries', {'range': '1h'}),
      safe('network.wireless', 'status', {}),
      safe('system', 'info', {}),
      safe('luci-rpc', 'getDHCPLeases', {}),
    ]);
    final summary = results[0].$1;
    final live = results[1].$1;
    final series = results[2].$1;
    final wifi = results[3].$1;
    final system = results[4].$1;
    if (summary == null && live == null && wifi == null && system == null) {
      throw RouterApiException(results[0].$2 ?? '无法读取路由器状态');
    }
    return RouterSnapshot(
      fetchedAt: DateTime.now(),
      summary: summary == null ? null : TrafficSummary.fromJson(summary),
      live: live == null ? null : LiveRate.fromJson(live),
      series: series == null ? null : TrafficSeries.fromJson(series),
      radios: wifi == null ? const [] : WifiRadio.parseAll(wifi),
      dhcpDevices:
          results[5].$1 == null ? const [] : DhcpDevice.parseAll(results[5].$1),
      uptimeSeconds:
          system?['uptime'] is num ? (system!['uptime'] as num).toInt() : null,
      trafficError: results[0].$2 ?? results[1].$2,
      wifiError: results[3].$2,
    );
  }

  void close() => _client.close();
}
