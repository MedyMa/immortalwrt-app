import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Only reads same-origin router cache URLs supplied by TrafficIcons.
class TrafficIcon extends StatefulWidget {
  const TrafficIcon({super.key, required this.name, this.uri, this.load});
  final String name;
  final Uri? uri;
  final Future<Uint8List?> Function(Uri)? load;
  @override
  State<TrafficIcon> createState() => _TrafficIconState();
}

class _TrafficIconState extends State<TrafficIcon> {
  ScrollPosition? _position;
  Uint8List? _bytes;
  bool _started = false;
  DateTime? _attemptedAt;

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
        (_bytes == null &&
            _attemptedAt != null &&
            DateTime.now().difference(_attemptedAt!).inSeconds >= 60)) {
      _started = false;
      _bytes = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryLoad());
    }
  }

  void _scrollEnded() {
    if (_position?.isScrollingNotifier.value == false) _tryLoad();
  }

  Future<void> _tryLoad() async {
    if (!mounted ||
        _started ||
        widget.uri == null ||
        widget.uri!.path.endsWith('.svg')) {
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
    final uri = widget.uri!;
    final bytes = await (widget.load ?? _loadRaster)(uri);
    if (mounted && widget.uri == uri) setState(() => _bytes = bytes);
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_scrollEnded);
    super.dispose();
  }

  Widget _fallback(BuildContext context) {
    final name = widget.name.trim();
    final website = RegExp(
      r'^[a-z0-9.-]+\.[a-z]{2,}$',
      caseSensitive: false,
    ).hasMatch(name);
    final letters = website
        ? name.split('.').first.characters.take(2).toString().toUpperCase()
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
    final uri = widget.uri;
    Widget svg = uri?.path.endsWith('.svg') == true
        ? SvgPicture.network(
            uri.toString(),
            fit: BoxFit.contain,
            placeholderBuilder: (_) => fallback,
            errorBuilder: (_, __, ___) => fallback,
          )
        : fallback;
    if (uri?.path.endsWith('.svg') == true &&
        RegExp(
          r'^[a-z0-9.-]+\.[a-z]{2,}$',
          caseSensitive: false,
        ).hasMatch(widget.name)) {
      svg = DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: svg),
      );
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: uri?.path.endsWith('.svg') == true
          ? svg
          : _bytes == null
          ? fallback
          : DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Image.memory(
                  _bytes!,
                  fit: BoxFit.contain,
                  cacheWidth: 64,
                  cacheHeight: 64,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              ),
            ),
    );
  }
}

final _rasterCache = <String, Future<Uint8List?>>{};
Future<Uint8List?> _loadRaster(Uri uri) {
  // At most 64 small decoded icons in the phone's session cache.
  if (_rasterCache.length >= 64 && !_rasterCache.containsKey(uri.toString())) {
    _rasterCache.remove(_rasterCache.keys.first);
  }
  return _rasterCache
      .putIfAbsent(uri.toString(), () async {
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
            return compute(decodeTrafficIcon, bytes.takeBytes());
          })().timeout(const Duration(seconds: 3));
        } catch (_) {
          return null;
        } finally {
          client.close();
        }
      })
      .then((bytes) {
        if (bytes == null) _rasterCache.remove(uri.toString());
        return bytes;
      });
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
