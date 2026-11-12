import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../services/website_host.dart';

/// Only reads same-origin router cache URLs supplied by TrafficIcons.
class TrafficIcon extends StatefulWidget {
  const TrafficIcon({
    super.key,
    required this.name,
    this.uri,
    this.alternatives = const [],
    this.load,
  });
  final String name;
  final Uri? uri;
  final List<Uri> alternatives;
  final Future<Uint8List?> Function(Uri)? load;
  @override
  State<TrafficIcon> createState() => _TrafficIconState();
}

class _TrafficIconState extends State<TrafficIcon> {
  ScrollPosition? _position;
  Uint8List? _bytes;
  Uri? _activeUri;
  bool _started = false;
  int _candidate = 0, _generation = 0;
  Uri? _renderFailure;
  DateTime? _attemptedAt;

  List<Uri> get _sources => {
    if (widget.uri != null) widget.uri!,
    ...widget.alternatives,
  }.take(4).toList();

  String? get _bundledArtwork {
    final name = widget.name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    if (name == 'apple-maps' ||
        _sources.any((uri) => uri.path.endsWith('/apple-maps.svg'))) {
      return 'apple-maps';
    }
    if (name == 'siri' ||
        _sources.any((uri) => uri.path.endsWith('/siri.svg'))) {
      return 'siri';
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.isScrollingNotifier.removeListener(_scrollEnded);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.isScrollingNotifier.addListener(_scrollEnded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryLoad());
  }

  @override
  void didUpdateWidget(TrafficIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.name != widget.name ||
        !listEquals(oldWidget.alternatives, widget.alternatives) ||
        (_bytes == null &&
            _attemptedAt != null &&
            DateTime.now().difference(_attemptedAt!).inSeconds >= 60)) {
      _started = false;
      _bytes = null;
      _activeUri = null;
      _renderFailure = null;
      _candidate = 0;
      _generation++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryLoad());
    }
  }

  void _scrollEnded() {
    if (_position?.isScrollingNotifier.value == false) _tryLoad();
  }

  Future<void> _tryLoad() async {
    if (!mounted || _started || _sources.isEmpty) {
      return;
    }
    if (_bundledArtwork != null) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y + box.size.height < 0 || y > MediaQuery.sizeOf(context).height) {
      return;
    }
    _started = true;
    _attemptedAt = DateTime.now();
    final generation = _generation;
    final sources = _sources;
    while (_candidate < sources.length) {
      final uri = sources[_candidate++];
      Uint8List? bytes;
      try {
        bytes = await (widget.load ?? _loadCachedIcon)(uri);
        if (bytes != null && (bytes.isEmpty || bytes.length > 65536)) {
          bytes = null;
        }
      } catch (_) {
        bytes = null;
      }
      if (!mounted || _generation != generation) return;
      if (bytes != null) {
        setState(() {
          _bytes = bytes;
          _activeUri = uri;
        });
        return;
      }
    }
  }

  Widget _unreadable(Widget fallback) {
    final uri = _activeUri;
    if (uri != null && _renderFailure != uri) {
      _renderFailure = uri;
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _bytes = null;
          _activeUri = null;
          _started = false;
        });
        _tryLoad();
      });
    }
    return fallback;
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_scrollEnded);
    super.dispose();
  }

  Widget _fallback(BuildContext context) {
    final name = widget.name.trim();
    final host = WebsiteHost.normalize(name);
    final website = host != null;
    final letters = host != null
        ? host
              .replaceFirst(RegExp(r'^www\.'), '')
              .split('.')
              .first
              .characters
              .take(2)
              .toString()
              .toUpperCase()
        : name.isEmpty
        ? '?'
        : name.characters.first.toUpperCase();
    const palette = [
      Color(0xFF00B4FF),
      Color(0xFFFF7A45),
      Color(0xFF36CFC9),
      Color(0xFFFF4D8D),
      Color(0xFF7C5CFF),
      Color(0xFFFFC53D),
      Color(0xFF40D97B),
      Color(0xFFFF9F1C),
      Color(0xFF5CD1FF),
      Color(0xFFB37FEB),
    ];
    var hash = 0;
    for (final code in name.toLowerCase().codeUnits) {
      hash = (hash * 31 + code) & 0xffffffff;
    }
    final color = website
        ? palette[hash % palette.length]
        : const Color(0xFF8B5CF6);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          letters,
          style: TextStyle(
            fontSize: website ? 10 : 13,
            fontWeight: FontWeight.w700,
            color: dark
                ? Color.lerp(color, Colors.white, .4)
                : Color.lerp(color, Colors.black, .3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback(context);
    final appleIcon = _bundledArtwork;
    // These source SVGs use styles/gradient inheritance that Flutter renders
    // differently from browsers. Bundle faithful 128 px raster counterparts.
    if (appleIcon != null) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Image.asset(
          'assets/traffic-icons/$appleIcon.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    Widget artwork = fallback;
    if (_bytes != null) {
      artwork = _activeUri?.path.endsWith('.svg') == true
          ? SvgPicture.memory(
              _bytes!,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => fallback,
              errorBuilder: (_, __, ___) => _unreadable(fallback),
            )
          : Image.memory(
              _bytes!,
              fit: BoxFit.contain,
              cacheWidth: 64,
              cacheHeight: 64,
              errorBuilder: (_, __, ___) => _unreadable(fallback),
            );
      if (WebsiteHost.normalize(widget.name) != null ||
          _activeUri?.path.startsWith('/traffic-site-icons/') == true) {
        artwork = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Padding(padding: const EdgeInsets.all(2), child: artwork),
        );
      }
    }
    return SizedBox(width: 28, height: 28, child: artwork);
  }
}

class _CachedTrafficIcon {
  late final Future<Uint8List?> result;
  final createdAt = DateTime.now();
  bool failed = false;
}

final _iconCache = <String, _CachedTrafficIcon>{};
final _iconWaiters = Queue<Completer<void>>();
int _activeRequests = 0;

Future<Uint8List?> _loadCachedIcon(Uri uri) {
  if (!const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !const [
        '/traffic-site-icons/',
        '/traffic-icons/',
        '/luci-static/resources/traffic/icons/',
      ].any(uri.path.startsWith)) {
    return Future.value(null);
  }
  final key = uri.toString();
  final cached = _iconCache.remove(key);
  if (cached != null &&
      DateTime.now().difference(cached.createdAt) <
          (cached.failed
              ? const Duration(minutes: 1)
              : const Duration(hours: 1))) {
    _iconCache[key] = cached;
    return cached.result;
  }
  if (_iconCache.length >= 64) {
    _iconCache.remove(_iconCache.keys.first);
  }
  final entry = _CachedTrafficIcon();
  _iconCache[key] = entry;
  entry.result =
      (() async {
        // Bound both concurrent connections and work waiting after fast scrolls.
        if (_activeRequests >= 4) {
          if (_iconWaiters.length >= 24) return null;
          final waiter = Completer<void>();
          _iconWaiters.add(waiter);
          await waiter.future;
        } else {
          _activeRequests++;
        }
        final client = http.Client();
        try {
          return await (() async {
            final response = await client.send(
              http.Request('GET', uri)..followRedirects = false,
            );
            if (response.statusCode != 200 ||
                (response.contentLength ?? 0) > 65536) {
              return null;
            }
            final bytes = BytesBuilder(copy: false);
            await for (final chunk in response.stream) {
              if (bytes.length + chunk.length > 65536) return null;
              bytes.add(chunk);
            }
            final data = bytes.takeBytes();
            if (uri.path.endsWith('.svg')) {
              return data;
            }
            return compute(decodeTrafficIcon, data);
          })().timeout(const Duration(seconds: 3));
        } catch (_) {
          return null;
        } finally {
          client.close();
          if (_iconWaiters.isNotEmpty) {
            _iconWaiters.removeFirst().complete();
          } else {
            _activeRequests--;
          }
        }
      })().then((bytes) {
        entry.failed = bytes == null;
        return bytes;
      });
  return entry.result;
}

Uint8List? decodeTrafficIcon(Uint8List bytes) {
  if (bytes.length > 65536) return null;
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width > 1024 || info.height > 1024) return null;
    final image = decoder!.decodeFrame(0);
    if (image == null) return null;
    return img.encodePng(
      img.copyResize(image, width: 64, height: 64, maintainAspect: true),
    );
  } catch (_) {
    return null;
  }
}
