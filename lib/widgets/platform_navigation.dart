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
  const _IosTabBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_IosTabBar> createState() => _IosTabBarState();
}

class _IosTabBarState extends State<_IosTabBar> {
  MethodChannel? _channel;

  void _onCreated(int viewId) {
    final channel = MethodChannel('com.medyma.immortalwrt/navigation/$viewId');
    _channel = channel;
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
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _channel?.invokeMethod<void>('setTab', widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return SizedBox(
        height: 50 + MediaQuery.viewPaddingOf(context).bottom,
        child: UiKitView(
          viewType: 'com.medyma.immortalwrt/system-tab-bar',
          creationParams: {'selectedIndex': widget.selectedIndex},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onCreated,
        ),
      );
    }
    return CupertinoTabBar(
      currentIndex: widget.selectedIndex,
      onTap: widget.onSelected,
      activeColor: _blue,
      backgroundColor: _cardOf(context),
      items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: '总览'),
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
      'iphone' => CupertinoIcons.device_phone_portrait,
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
