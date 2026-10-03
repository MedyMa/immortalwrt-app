import 'package:http/http.dart' as http;

class TrafficIcons {
  TrafficIcons._(this.baseUrl, this.slugs, this.domains, this.websites);

  final Uri baseUrl;
  final Set<String> slugs;
  final Map<String, String> domains;
  final Map<String, String> websites;

  static const _aliases = <String, String>{
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
  ]) {
    final slugs = indexText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => RegExp(r'^[a-z0-9-]+$').hasMatch(line))
        .toSet();
    final domains = <String, String>{};
    for (final line in domainText.split(RegExp(r'\r?\n'))) {
      final fields = line.trim().split('\t');
      if (fields.length == 2 &&
          RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(fields[0]) &&
          RegExp(r'^[a-z0-9-]+$').hasMatch(fields[1]) &&
          slugs.contains(fields[1])) {
        domains[fields[0]] = fields[1];
      }
    }
    return TrafficIcons._(baseUrl, slugs, domains, _websiteIndex(websiteText));
  }

  static Map<String, String> _websiteIndex(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final fields = line.trim().split('\t');
      if (fields.length < 2 || fields.length > 3) continue;
      final host = fields[0];
      if (!RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(host) ||
          host.contains('..')) {
        continue;
      }
      if (fields[1] != '$host.png' && fields[1] != '$host.ico') continue;
      if (fields.length == 3 && !RegExp(r'^\d+$').hasMatch(fields[2])) continue;
      result[host] = fields[1] + (fields.length == 3 ? '?v=${fields[2]}' : '');
    }
    return result;
  }

  Future<TrafficIcons> refreshWebsites() async {
    try {
      final response = await http
          .get(baseUrl.replace(path: '/traffic-site-icons/websites.tsv'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 &&
          response.bodyBytes.length <= 4 * 1024 * 1024) {
        return TrafficIcons._(
          baseUrl,
          slugs,
          domains,
          _websiteIndex(response.body),
        );
      }
    } catch (_) {
      /* Keep the last valid index while offline. */
    }
    return this;
  }

  static Future<TrafficIcons> load(Uri baseUrl, {http.Client? client}) async {
    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    Future<String> read(String path) async {
      try {
        final response = await httpClient
            .get(baseUrl.replace(path: path))
            .timeout(const Duration(seconds: 8));
        return response.statusCode == 200 ? response.body : '';
      } catch (_) {
        return '';
      }
    }

    try {
      final results = await Future.wait([
        read('/luci-static/resources/traffic/icons/index.txt'),
        read('/luci-static/resources/traffic/icons/domains.tsv'),
        read('/traffic-site-icons/websites.tsv'),
      ]);
      return TrafficIcons.fromIndexes(
        baseUrl,
        results[0],
        results[1],
        results[2],
      );
    } finally {
      if (ownedClient) httpClient.close();
    }
  }

  Uri? iconUri(String name) {
    final candidate = _slug(_aliases[name] ?? name);
    String? key = slugs.contains(candidate) ? candidate : null;
    final host = name.toLowerCase();
    if (key == null && RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(host)) {
      final labels = host.split('.');
      for (var i = 0; i < labels.length - 1; i++) {
        key = domains[labels.skip(i).join('.')];
        if (key != null) break;
      }
      final root = RegExp(
        r'^([a-z0-9][a-z0-9-]*)\.(?:com|net|org|io|cn|ai|app|dev|co|tv|me|com\.cn|net\.cn|org\.cn)$',
      ).firstMatch(host)?.group(1);
      if (key == null && root != null && slugs.contains(root)) key = root;
    }
    if (key == null) {
      final file = websites[host];
      return file == null ? null : baseUrl.resolve('/traffic-site-icons/$file');
    }
    return baseUrl.replace(
      path: '/luci-static/resources/traffic/icons/$key.svg',
    );
  }

  static String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
