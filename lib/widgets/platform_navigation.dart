part of '../main.dart';

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
            icon: Icon(CupertinoIcons.device_phone_portrait), label: '设备'),
        BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.wifi), label: 'Wi-Fi'),
        BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar), label: '流量'),
      ],
    );
  }
}
