import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'website_host.dart';

class TrafficIcons {
  TrafficIcons._(
    this.baseUrl,
    this.slugs,
    this.domains,
    this.websites,
    this.cachedSlugs,
  );

  final Uri baseUrl;
  final Set<String> slugs;
  final Map<String, String> domains;
  final Map<String, String> websites;
  final Set<String> cachedSlugs;

  static const _aliases = <String, String>{
    '小米': 'xiaomi',
    '红米': 'xiaomi',
    '联想': 'lenovo',
    '华为': 'huawei',
    '苹果': 'apple',
    '荣耀': 'honor',
    '三星': 'samsung',
    '一加': 'oneplus',
    '华硕': 'asus',
    '戴尔': 'dell',
    '惠普': 'hp',
    '群晖': 'synology',
    '威联通': 'qnap',
    '海康威视': 'hikvision',
    '佳能': 'canon',
    '大疆': 'dji',
    'samsung.com.cn': 'samsung',
    'samsungcloudcn.com': 'samsung',
    'samsunggalaxy.com.cn': 'samsung',
    'aibixby.com.cn': 'samsung',
    'srcgsre.com': 'samsung',
    'producthunt.com': 'producthunt',
    'brandfetch.io': 'brandfetch',
    'trip.com': 'trip-com',
    'zohopublic.com.cn': 'zoho',
    'Product Hunt': 'producthunt',
    'DigiCert': 'certificate',
    'digicert.com': 'certificate',
    'Rockstar': 'rockstargames',
    'Rockstar Games': 'rockstargames',
    'Square Enix': 'squareenix',
    'Steam Deck': 'steamdeck',
    'Mihoyo Cn': 'hoyoverse',
    'PlayStation 5': 'playstation5',
    'PlayStation 4': 'playstation4',
    'PlayStation 3': 'playstation3',
    'PlayStation 2': 'playstation2',
    'PlayStation Vita': 'playstationvita',
    'PlayStation Portable': 'playstationportable',
    'Blue Archive': 'bluearchive',
    'Heroic Games Launcher': 'heroicgameslauncher',
    'Game Science': 'gamescience',
    'Roblox Studio': 'robloxstudio',
    'YouTube Gaming': 'youtubegaming',
    'WangSuKeJi': 'cdn',
    'WangXinKeJi': 'cdn',
    'z1cdn.com': 'cdn',
  };

  factory TrafficIcons.fromIndexes(
    Uri baseUrl,
    String indexText,
    String domainText, [
    String websiteText = '',
    String cachedIndexText = '',
  ]) {
    final slugs = _index(indexText);
    final domains = <String, String>{};
    for (final line in domainText.split(RegExp(r'\r?\n'))) {
      final fields = line.trim().split('\t');
      if (fields.length == 2 &&
          WebsiteHost.normalize(fields[0]) == fields[0] &&
          RegExp(r'^[a-z0-9-]+$').hasMatch(fields[1]) &&
          slugs.contains(fields[1])) {
        domains[fields[0]] = fields[1];
      }
    }
    return TrafficIcons._(
      baseUrl.replace(path: '/', query: '', fragment: '', userInfo: ''),
      slugs,
      Map.unmodifiable(domains),
      _websiteIndex(websiteText),
      _index(cachedIndexText),
    );
  }

  static Set<String> _index(String text) => Set.unmodifiable(
    text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.length <= 128 && RegExp(r'^[a-z0-9-]+$').hasMatch(line),
        ),
  );

  static Map<String, String> _websiteIndex(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final fields = line.trim().split('\t');
      if (fields.length < 2 || fields.length > 3) continue;
      final host = fields[0];
      if (WebsiteHost.normalize(host) != host) {
        continue;
      }
      if (fields[1] != '$host.png' &&
          fields[1] != '$host.ico' &&
          fields[1] != '$host.svg') {
        continue;
      }
      if (fields.length == 3 && !RegExp(r'^\d{1,16}$').hasMatch(fields[2])) {
        continue;
      }
      result[host] = fields[1] + (fields.length == 3 ? '?v=${fields[2]}' : '');
    }
    return Map.unmodifiable(result);
  }

  // Static resources carry no RPC cookie/token. Do not follow a captive portal
  // or router redirect to another origin; bound the stream before buffering it.
  static Future<String?> _read(http.Client client, Uri url, int limit) async {
    try {
      return await (() async {
        final response = await client.send(
          http.Request('GET', url)..followRedirects = false,
        );
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > limit) {
          return null;
        }
        if ((response.headers['content-type'] ?? '').toLowerCase().startsWith(
          'text/html',
        )) {
          return null;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit) return null;
          bytes.add(chunk);
        }
        return utf8.decode(bytes.takeBytes());
      })().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  Future<TrafficIcons> refreshWebsites() async {
    // Recover the complete catalog after an initial offline/upgrade failure.
    if (slugs.isEmpty) {
      final recovered = await TrafficIcons.load(baseUrl);
      return TrafficIcons._(
        baseUrl,
        recovered.slugs,
        recovered.domains,
        recovered.websites.isEmpty ? websites : recovered.websites,
        recovered.cachedSlugs.isEmpty ? cachedSlugs : recovered.cachedSlugs,
      );
    }
    final client = http.Client();
    try {
      final texts = await Future.wait([
        _read(
          client,
          baseUrl.resolve('/traffic-site-icons/websites.tsv'),
          4 * 1024 * 1024,
        ),
        _read(client, baseUrl.resolve('/traffic-icons/index.txt'), 128 * 1024),
      ]);
      final sites = texts[0] == null ? websites : _websiteIndex(texts[0]!);
      final apps = texts[1] == null ? cachedSlugs : _index(texts[1]!);
      return TrafficIcons._(
        baseUrl,
        slugs,
        domains,
        sites.isEmpty && (texts[0]?.trim().isNotEmpty ?? false)
            ? websites
            : sites,
        apps.isEmpty && (texts[1]?.trim().isNotEmpty ?? false)
            ? cachedSlugs
            : apps,
      );
    } finally {
      client.close();
    }
  }

  static Future<TrafficIcons> load(Uri baseUrl, {http.Client? client}) async {
    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    final origin = baseUrl.replace(
      path: '/',
      query: '',
      fragment: '',
      userInfo: '',
    );

    try {
      final results = await Future.wait([
        _read(
          httpClient,
          origin.resolve('/luci-static/resources/traffic/icons/index.txt'),
          128 * 1024,
        ),
        _read(
          httpClient,
          origin.resolve('/luci-static/resources/traffic/icons/domains.tsv'),
          1024 * 1024,
        ),
        _read(
          httpClient,
          origin.resolve('/traffic-site-icons/websites.tsv'),
          4 * 1024 * 1024,
        ),
        _read(
          httpClient,
          origin.resolve('/traffic-icons/index.txt'),
          128 * 1024,
        ),
      ]);
      return TrafficIcons.fromIndexes(
        origin,
        results[0] ?? '',
        results[1] ?? '',
        results[2] ?? '',
        results[3] ?? '',
      );
    } finally {
      if (ownedClient) httpClient.close();
    }
  }

  Uri? iconUri(String name) {
    final candidates = iconUris(name);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Indexed files only, with actual fallbacks when artwork is unreadable.
  List<Uri> iconUris(String name) {
    final host = WebsiteHost.normalize(name);
    final candidate = _slug(_aliases[name] ?? _aliases[host] ?? host ?? name);
    bool available(String key) =>
        slugs.contains(key) || cachedSlugs.contains(key);
    String? key = available(candidate) ? candidate : null;
    if (key == null && host != null) {
      for (final lookup in [host, ...WebsiteHost.parents(host)]) {
        key = domains[lookup];
        if (key != null) break;
      }
      final root = RegExp(
        r'^([a-z0-9][a-z0-9-]*)\.(?:com|net|org|io|cn|ai|app|dev|co|tv|me|com\.cn|net\.cn|org\.cn)$',
      ).firstMatch(host)?.group(1);
      if (key == null && root != null && available(root)) key = root;
    }
    final result = <Uri>[];
    if (key != null) {
      if (slugs.contains(key)) {
        result.add(
          baseUrl.resolve('/luci-static/resources/traffic/icons/$key.svg'),
        );
      }
      if (cachedSlugs.contains(key)) {
        result.add(baseUrl.resolve('/traffic-icons/$key.svg'));
      }
    }
    if (host != null) {
      for (final lookup in [host, ...WebsiteHost.parents(host)]) {
        final file = websites[lookup];
        if (file != null) {
          result.add(baseUrl.resolve('/traffic-site-icons/$file'));
        }
      }
    }
    return List.unmodifiable(result.toSet().take(4));
  }

  static String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
