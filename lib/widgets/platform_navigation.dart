part of '../main.dart';

class _IosSettingsButton extends StatefulWidget {
  const _IosSettingsButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_IosSettingsButton> createState() => _IosSettingsButtonState();
}

class _IosSettingsButtonState extends State<_IosSettingsButton> {
  MethodChannel? _channel;
  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: UiKitView(
      viewType: 'com.medyma.immortalwrt/settings-button',
      onPlatformViewCreated: (id) {
        _channel = MethodChannel('com.medyma.immortalwrt/settings/$id');
        _channel!.setMethodCallHandler((call) async {
          if (call.method == 'openSettings') widget.onPressed();
        });
      },
    ),
  );
}

/// The iOS device embeds a system UITabBar. Widget tests on non-iOS hosts use
/// CupertinoTabBar so the selection contract remains testable without UIKit.
class _IosTabBar extends StatefulWidget {
  const _IosTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.visible,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueListenable<bool> visible;

  @override
  State<_IosTabBar> createState() => _IosTabBarState();
}

class _IosTabBarState extends State<_IosTabBar> {
  MethodChannel? _channel;
  bool get _native => !kIsWeb && Platform.isIOS;
  bool get _show =>
      MediaQuery.accessibleNavigationOf(context) || widget.visible.value;

  @override
  void initState() {
    super.initState();
    widget.visible.addListener(_syncVisibility);
  }

  void _syncVisibility() {
    _channel?.invokeMethod<void>('setVisible', _show);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  void _onCreated(int viewId) {
    final channel = MethodChannel('com.medyma.immortalwrt/navigation/$viewId');
    _channel = channel;
    _syncVisibility();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'selectTab' && call.arguments is int) {
        final index = call.arguments as int;
        if (index >= 0 && index < 4) widget.onSelected(index);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _IosTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      oldWidget.visible.removeListener(_syncVisibility);
      widget.visible.addListener(_syncVisibility);
      _syncVisibility();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _channel?.invokeMethod<void>('setTab', widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    widget.visible.removeListener(_syncVisibility);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget bar;
    if (_native) {
      bar = SizedBox(
        height: 72 + MediaQuery.viewPaddingOf(context).bottom,
        child: UiKitView(
          viewType: 'com.medyma.immortalwrt/system-tab-bar',
          creationParams: {
            'selectedIndex': widget.selectedIndex,
            'visible': _show,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onCreated,
        ),
      );
    } else {
      bar = CupertinoTabBar(
        currentIndex: widget.selectedIndex,
        onTap: widget.onSelected,
        activeColor: _blue,
        backgroundColor: _cardOf(context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: '总览',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.device_phone_portrait),
            label: '设备',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.wifi),
            label: 'Wi-Fi',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: '流量',
          ),
        ],
      );
    }
    return AnimatedBuilder(
      key: const ValueKey('ios-navigation-shell'),
      animation: widget.visible,
      child: bar,
      builder: (context, child) {
        final show = _show;
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _NavigationGeometry.duration;
        // UIKit animates its own glass view; fading a platform view in Flutter
        // can leave a stale native surface. Hosts without UIKit use this fallback.
        return IgnorePointer(
          ignoring: !show,
          child: ExcludeFocus(
            excluding: !show,
            child: ExcludeSemantics(
              excluding: !show,
              child: _native
                  ? child!
                  : AnimatedSlide(
                      offset: show ? Offset.zero : const Offset(0, 1.4),
                      duration: duration,
                      child: AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: duration,
                        child: child,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Native system material samples the underlying page and follows iOS
/// accessibility settings. Other platforms retain their existing glass surface.
class _IosGlassSurface extends StatelessWidget {
  const _IosGlassSurface({
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.pageGlassOnAndroid = false,
  });
  final Widget child;
  final BorderRadius radius;
  final bool pageGlassOnAndroid;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isIOS) {
      if (pageGlassOnAndroid &&
          Theme.of(context).platform == TargetPlatform.android) {
        return _StatusBarGlass(radius: radius, child: child);
      }
      return _GlassSurface(radius: radius, child: child);
    }
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: UiKitView(
                viewType: 'com.medyma.immortalwrt/glass-surface',
                creationParams: {'sheet': radius != BorderRadius.zero},
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AppleButton extends StatefulWidget {
  const _AppleButton({
    required this.title,
    required this.onPressed,
    this.symbol = 'link',
    this.prominent = true,
  });
  final String title;
  final VoidCallback onPressed;
  final String symbol;
  final bool prominent;
  @override
  State<_AppleButton> createState() => _AppleButtonState();
}

class _AppleButtonState extends State<_AppleButton> {
  MethodChannel? _channel;
  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return SizedBox(
        height: math.max(50, MediaQuery.textScalerOf(context).scale(17) + 28),
        child: UiKitView(
          viewType: 'com.medyma.immortalwrt/action-button',
          creationParams: {
            'title': widget.title,
            'symbol': widget.symbol,
            'prominent': widget.prominent,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) {
            _channel = MethodChannel('com.medyma.immortalwrt/action/$id');
            _channel!.setMethodCallHandler((call) async {
              if (call.method == 'activate') widget.onPressed();
            });
          },
        ),
      );
    }
    final child = Text(widget.title);
    return widget.prominent
        ? CupertinoButton.filled(onPressed: widget.onPressed, child: child)
        : CupertinoButton(onPressed: widget.onPressed, child: child);
  }
}

class _AppleSymbol extends StatelessWidget {
  const _AppleSymbol(
    this.name, {
    required this.fallback,
    this.size = 18,
    required this.color,
  });
  final String name;
  final IconData fallback;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return Icon(fallback, size: size, color: color);
    }
    if (!kIsWeb && Platform.isIOS) {
      return SizedBox.square(
        dimension: size,
        child: UiKitView(
          key: ValueKey('$name-${color.toARGB32()}-$size'),
          viewType: 'com.medyma.immortalwrt/symbol',
          creationParams: {
            'name': name,
            'size': size,
            'color': color.toARGB32(),
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    final icon = switch (name) {
      'xmark' => CupertinoIcons.xmark,
      'doc.on.doc' => CupertinoIcons.doc_on_doc,
      'chevron.up' => CupertinoIcons.chevron_up,
      'chevron.down' => CupertinoIcons.chevron_down,
      'iphone' => CupertinoIcons.device_phone_portrait,
      'applewatch' => CupertinoIcons.time,
      'hifispeaker' => CupertinoIcons.hifispeaker,
      'lightbulb' => CupertinoIcons.lightbulb,
      'powerplug' => CupertinoIcons.bolt,
      'sensor' => CupertinoIcons.antenna_radiowaves_left_right,
      'circle.dotted' => CupertinoIcons.circle,
      'washer' => CupertinoIcons.cube_box,
      'house' => CupertinoIcons.house,
      'ipad' => CupertinoIcons.device_phone_landscape,
      'laptopcomputer' => CupertinoIcons.device_laptop,
      'tv' => CupertinoIcons.tv,
      'externaldrive' => CupertinoIcons.archivebox,
      'gamecontroller' => CupertinoIcons.game_controller,
      'printer' => CupertinoIcons.printer,
      'camera' => CupertinoIcons.camera,
      'wifi.router' => CupertinoIcons.wifi,
      'square.stack.3d.up' => CupertinoIcons.square_stack_3d_up,
      'desktopcomputer' => CupertinoIcons.desktopcomputer,
      'wifi' => CupertinoIcons.wifi,
      _ => CupertinoIcons.chevron_right,
    };
    return Icon(icon, size: size, color: color);
  }
}
