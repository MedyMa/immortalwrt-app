/// Conservative cache lookup, shared by the catalog and its fallback avatars.
/// Unknown suffixes remain exact-only; tenants never inherit a platform icon.
abstract final class WebsiteHost {
  static String? normalize(String value) {
    var host = value.trim().toLowerCase();
    if (host.startsWith('https://') || host.startsWith('http://')) {
      final uri = Uri.tryParse(host);
      if (uri == null || uri.userInfo.isNotEmpty) return null;
      host = uri.host;
    }
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    if (host.length > 253 || !host.contains('.')) return null;
    final labels = host.split('.');
    if (labels.any(
      (part) =>
          part.isEmpty ||
          part.length > 63 ||
          !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(part),
    )) {
      return null;
    }
    final tld = labels.last;
    if ((!RegExp(r'^[a-z]{2,}$').hasMatch(tld) && !tld.startsWith('xn--')) ||
        const {
          'local',
          'localhost',
          'internal',
          'invalid',
          'test',
          'example',
          'home',
          'lan',
        }.contains(tld)) {
      return null;
    }
    return host;
  }

  static Iterable<String> parents(String host) sync* {
    final labels = host.split('.');
    // Regional object-storage namespaces are not a fixed tenant boundary.
    if (host.endsWith('.amazonaws.com')) return;
    var suffixLabels = 0;
    for (final suffix in {..._compound, ..._shared}) {
      if (host.endsWith('.$suffix')) {
        final size = suffix.split('.').length;
        if (size > suffixLabels) suffixLabels = size;
      }
    }
    if (suffixLabels == 0 && _single.contains(labels.last)) suffixLabels = 1;
    if (suffixLabels == 0) return;
    for (var i = 1; i < labels.length - suffixLabels; i++) {
      yield labels.skip(i).join('.');
    }
  }

  static const _shared = {
    'github.io',
    'gitlab.io',
    'codeberg.page',
    'pages.dev',
    'workers.dev',
    'vercel.app',
    'netlify.app',
    'appspot.com',
    'firebaseapp.com',
    'web.app',
    'blogspot.com',
    'blogspot.co.uk',
    'wordpress.com',
    'notion.site',
    'cloudfront.net',
    'azurewebsites.net',
    'azurestaticapps.net',
    'herokuapp.com',
    'readthedocs.io',
    'readthedocs.org',
    'surge.sh',
    'duckdns.org',
    'ddns.net',
    'synology.me',
    'myqnapcloud.com',
    'r2.dev',
  };
  static const _compound = {
    'com.cn',
    'net.cn',
    'org.cn',
    'gov.cn',
    'edu.cn',
    'co.uk',
    'org.uk',
    'ac.uk',
    'gov.uk',
    'net.uk',
    'com.au',
    'net.au',
    'org.au',
    'edu.au',
    'gov.au',
    'co.jp',
    'ne.jp',
    'or.jp',
    'ac.jp',
    'go.jp',
    'co.nz',
    'net.nz',
    'org.nz',
    'co.kr',
    'com.tw',
    'com.hk',
    'com.sg',
    'com.br',
    'co.in',
    'co.za',
  };
  static const _single = {
    'com',
    'net',
    'org',
    'io',
    'cn',
    'ai',
    'app',
    'dev',
    'co',
    'tv',
    'me',
  };
}
