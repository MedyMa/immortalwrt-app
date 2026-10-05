import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/router_models.dart';

class RouterApiException implements Exception {
  const RouterApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RouterPermissionException extends RouterApiException {
  const RouterPermissionException(String method)
    : super('没有读取 $method 的权限（ubus 代码 6）');
}

class RouterMethodUnavailableException extends RouterApiException {
  const RouterMethodUnavailableException(String object, String method)
    : super(
        object == 'router.status'
            ? '请安装或更新路由器独立状态组件 rpcd-mod-router-status'
            : '$object.$method 不可用',
      );
}

class RouterSessionExpiredException extends RouterApiException {
  const RouterSessionExpiredException() : super('登录会话已失效');
}

class RouterAccessDeniedException extends RouterApiException {
  const RouterAccessDeniedException() : super('账号无此页面的读取权限，请检查 ubus ACL');
}

enum RouterSection { all, overview, devices, wifi, traffic, live }

class _ReadSpec {
  const _ReadSpec(this.key, this.object, this.method, [this.args = const {}]);
  final String key;
  final String object;
  final String method;
  final Map<String, dynamic> args;
}

class _ReadResult {
  const _ReadResult(this.key, this.data, this.error);
  final String key;
  final Map<String, dynamic>? data;
  final RouterApiException? error;
}

class RouterApi {
  RouterApi(this.baseUrl, {http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now {
    validateUrl(baseUrl.toString());
  }

  final Uri baseUrl;
  final http.Client _client;
  final DateTime Function() _clock;
  String? _session;
  DateTime? _lastSessionActivity;
  Duration? _sessionIdleTimeout;
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
    String object,
    String method,
    Map<String, dynamic> args, {
    bool login = false,
  }) async {
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
    } on TimeoutException {
      throw const RouterApiException('连接超时，请检查路由器或远程入口');
    } on HandshakeException {
      throw const RouterApiException('TLS 证书验证失败，请检查远程地址和证书');
    } on SocketException catch (error) {
      final dns =
          error.message.contains('host lookup') ||
          error.message.toLowerCase().contains('dns');
      throw RouterApiException(dns ? 'DNS 解析失败，请检查域名和网络' : '无法连接路由器，请检查地址和网络');
    } on http.ClientException {
      throw const RouterApiException('网络请求失败，请检查远程入口');
    }
    if (response.statusCode != 200) {
      throw RouterApiException('路由器返回 HTTP ${response.statusCode}');
    }
    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['result'] is! List) {
        final detail = payload is Map && payload['error'] is Map
            ? '${(payload['error'] as Map)['message'] ?? ''}'
            : '';
        if (detail.toLowerCase() == 'access denied') {
          if (login) throw const RouterApiException('登录失败，请检查用户名和密码');
          throw RouterPermissionException('$object.$method');
        }
        if (!login &&
            (detail.toLowerCase().contains('not found') ||
                detail.toLowerCase().contains('no such'))) {
          throw RouterMethodUnavailableException(object, method);
        }
        throw RouterApiException(
          detail.isEmpty
              ? '$object.$method 响应格式不正确'
              : '$object.$method：$detail',
        );
      }
      final result = payload['result'] as List;
      if (result.isEmpty || result[0] != 0) {
        if (result.isNotEmpty && result[0] == 6) {
          if (login) throw const RouterApiException('登录失败，请检查用户名和密码');
          throw RouterPermissionException('$object.$method');
        }
        if (!login && result.isNotEmpty && (result[0] == 3 || result[0] == 4)) {
          throw RouterMethodUnavailableException(object, method);
        }
        throw RouterApiException(
          'ubus 拒绝 $object.$method（代码 ${result.isEmpty ? '?' : result[0]}）',
        );
      }
      if (!login) _lastSessionActivity = _clock();
      if (result.length < 2 || result[1] is! Map) return {};
      return (result[1] as Map).map((key, value) => MapEntry('$key', value));
    } on FormatException {
      throw const RouterApiException('路由器返回了无效 JSON');
    }
  }

  Future<void> login(String username, String password) async {
    final result = await _call('session', 'login', {
      'username': username,
      'password': password,
    }, login: true);
    final session = result['ubus_rpc_session'];
    if (session is! String || session.isEmpty) {
      throw const RouterApiException('登录失败，请检查用户名和密码');
    }
    _session = session;
    final timeout = result['timeout'];
    final seconds = timeout is int && timeout >= 0 ? timeout : 300;
    _sessionIdleTimeout = seconds == 0 ? null : Duration(seconds: seconds);
    _lastSessionActivity = _clock();
  }

  Future<RouterSnapshot> fetch({
    RouterSection section = RouterSection.all,
    RouterSnapshot? previous,
  }) async {
    final lastActivity = _lastSessionActivity;
    final idleTimeout = _sessionIdleTimeout;
    if (lastActivity != null &&
        idleTimeout != null &&
        _clock().difference(lastActivity) >= idleTimeout) {
      throw const RouterSessionExpiredException();
    }
    const summary = _ReadSpec('summary', 'luci.traffic', 'getSummary');
    const live = _ReadSpec('live', 'luci.traffic', 'getLive');
    const series = _ReadSpec('series', 'luci.traffic', 'getSeries', {
      'range': '24h',
    });
    const window = _ReadSpec('window', 'luci.traffic', 'getHourly', {
      'hours': 24,
    });
    const wifi = _ReadSpec('wifi', 'router.status', 'getWirelessStatus');
    const wifiHistory = _ReadSpec(
      'wifiHistory',
      'router.status',
      'getWirelessHistory',
    );
    const system = _ReadSpec('system', 'system', 'info');
    const metrics = _ReadSpec('metrics', 'router.status', 'getSystemMetrics');
    const sfp = _ReadSpec('sfp', 'luci.sfp-status', 'getStatuses');
    const ppe = _ReadSpec('ppe', 'luci.turboacc', 'getMTKPPEStat');
    const devices = _ReadSpec('devices', 'luci-rpc', 'getDHCPLeases');
    const hints = _ReadSpec('hostHints', 'luci-rpc', 'getHostHints');
    final readHistory =
        section == RouterSection.wifi &&
        (previous?.wifiHistoryFetchedAt == null ||
            DateTime.now().difference(previous!.wifiHistoryFetchedAt!) >=
                const Duration(minutes: 1));
    final specs = switch (section) {
      RouterSection.overview => [
        summary,
        live,
        wifi,
        system,
        metrics,
        sfp,
        ppe,
      ],
      RouterSection.devices => [summary, devices, hints],
      RouterSection.wifi => [wifi, if (readHistory) wifiHistory],
      RouterSection.traffic => [window, series],
      RouterSection.live => [live],
      RouterSection.all => [
        summary,
        live,
        series,
        wifi,
        system,
        metrics,
        sfp,
        ppe,
        devices,
        hints,
      ],
    };
    Future<_ReadResult> safe(_ReadSpec spec) async {
      try {
        final result = await _call(spec.object, spec.method, spec.args);
        if (result['error'] is String) {
          throw RouterApiException(
            '${spec.object}.${spec.method}: ${result['error']}',
          );
        }
        return _ReadResult(spec.key, result, null);
      } on RouterApiException catch (error) {
        return _ReadResult(spec.key, null, error);
      }
    }

    final results = await Future.wait(specs.map(safe));
    final byKey = {for (final item in results) item.key: item};
    final successes = results.where((item) => item.data != null).length;
    if (successes == 0) {
      if (results.every((item) => item.error is RouterPermissionException)) {
        try {
          await _call('system', 'info', const {});
        } on RouterPermissionException {
          throw const RouterSessionExpiredException();
        }
      }
      final failure = results.first.error;
      final methodUnavailable = results.every((item) {
        final error = item.error;
        return error != null &&
            (error is RouterPermissionException ||
                error is RouterMethodUnavailableException ||
                error.message.contains('ubus 拒绝') ||
                error.message.contains('独立状态组件') ||
                (section == RouterSection.wifi &&
                    error.message.contains('响应格式不正确')));
      });
      if (!methodUnavailable) {
        throw failure ?? const RouterApiException('无法读取路由器状态');
      }
    }
    Map<String, dynamic>? data(String key) => byKey[key]?.data;
    String? error(String key) => byKey.containsKey(key)
        ? byKey[key]?.error?.message
        : switch (key) {
            'summary' => previous?.trafficError,
            'window' => previous?.windowError,
            'live' => previous?.liveError,
            'series' => previous?.seriesError,
            'wifi' => previous?.wifiError,
            'wifiHistory' => previous?.wifiHistoryError,
            'devices' => previous?.devicesError,
            'system' => previous?.systemError,
            'metrics' => previous?.metricsError,
            'sfp' => previous?.sfpError,
            'ppe' => previous?.ppeError,
            _ => null,
          };
    final summaryData = data('summary');
    final liveData = data('live');
    final seriesData = data('series');
    final wifiData = data('wifi');
    final wifiHistoryData = data('wifiHistory');
    final systemData = data('system');
    final metricsData = data('metrics');
    final sfpData = data('sfp');
    final firstCpu = metricsData == null
        ? null
        : CpuCounters.fromJson(metricsData['cpu']);
    var cpuCounters = firstCpu;
    if (firstCpu != null && previous?.cpuCounters == null) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      try {
        final second = await _call(
          'router.status',
          'getSystemMetrics',
          const {},
        );
        cpuCounters = CpuCounters.fromJson(second['cpu']) ?? firstCpu;
      } on RouterApiException {
        cpuCounters = firstCpu;
      }
    }
    final devicesData = data('devices');
    return RouterSnapshot(
      fetchedAt: DateTime.now(),
      summary: summaryData == null
          ? previous?.summary
          : TrafficSummary.fromJson(summaryData),
      trafficWindow: data('window') == null
          ? previous?.trafficWindow
          : TrafficSummary.fromHourly(data('window')),
      windowError: error('window'),
      live: liveData == null ? previous?.live : LiveRate.fromJson(liveData),
      series: seriesData == null
          ? previous?.series
          : TrafficSeries.fromJson(seriesData),
      radios: wifiData == null
          ? previous?.radios ?? const []
          : WifiRadio.parseAll(wifiData),
      wifiHistory: wifiHistoryData == null
          ? previous?.wifiHistory
          : WifiHistory.fromJson(wifiHistoryData),
      wifiHistoryFetchedAt: byKey.containsKey('wifiHistory')
          ? DateTime.now()
          : previous?.wifiHistoryFetchedAt,
      wifiHistoryError: error('wifiHistory'),
      hostHints: byKey.containsKey('hostHints')
          ? HostHint.parseAll(data('hostHints'))
          : previous?.hostHints ?? const [],
      hostHintsError: byKey.containsKey('hostHints')
          ? error('hostHints')
          : previous?.hostHintsError,
      dhcpDevices: devicesData == null
          ? previous?.dhcpDevices ?? const []
          : DhcpDevice.parseAll(devicesData),
      uptimeSeconds: systemData?['uptime'] is num
          ? (systemData!['uptime'] as num).toInt()
          : previous?.uptimeSeconds,
      memory: systemData == null
          ? previous?.memory
          : RouterMemory.fromSystemInfo(systemData),
      cpuCounters: byKey.containsKey('metrics')
          ? cpuCounters
          : previous?.cpuCounters,
      cpuUsagePercent: byKey.containsKey('metrics')
          ? cpuCounters?.usageSince(previous?.cpuCounters ?? firstCpu)
          : previous?.cpuUsagePercent,
      temperatures: byKey.containsKey('metrics')
          ? RouterTemperature.parseAll(
              metricsData?['temperatures'],
              serverEpoch: int.tryParse('${metricsData?['sampled_at']}'),
              receivedAt: DateTime.now(),
            )
          : previous?.temperatures ?? const [],
      sfpPorts: sfpData == null
          ? previous?.sfpPorts ?? const []
          : SfpPort.parseAll(sfpData),
      trafficError: error('summary'),
      liveError: error('live'),
      liveUnavailable: byKey.containsKey('live')
          ? byKey['live']?.error is RouterMethodUnavailableException ||
                byKey['live']?.error is RouterPermissionException
          : previous?.liveUnavailable ?? false,
      seriesError: error('series'),
      devicesError: error('devices'),
      systemError: error('system'),
      wifiError: error('wifi') == null
          ? null
          : byKey['wifi']?.error is RouterPermissionException
          ? '无线读取权限不足，请检查 router-status 只读权限'
          : error('wifi'),
      metricsError: error('metrics'),
      sfpError: error('sfp'),
      ppeTables: data('ppe') == null
          ? previous?.ppeTables ?? const []
          : PpeTable.parseAll(data('ppe')),
      ppeError: error('ppe'),
    );
  }

  void close() => _client.close();
}
