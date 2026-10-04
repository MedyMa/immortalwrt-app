part of '../main.dart';

/// Shared compact chrome dimensions; safe-area padding is added separately.
abstract final class _NavigationGeometry {
  static const radius = 40.0;
  static const height = 60.0;
  static const inset = 4.0;
  static const selectedRadius = 32.0;
  static const horizontalMargin = 12.0;
  static const bottomMargin = 8.0;
  static const labelSize = 11.0;
  static const hiddenSlide = 1.4;
  static const dragThreshold = 12.0;
  static const railBreakpoint = 700.0;
  static const blurSigma = 18.0;
  static const duration = Duration(milliseconds: 180);

  static double contentHeight(TextScaler scaler) =>
      height - 2 * inset + math.max(0, scaler.scale(labelSize) - labelSize) * 2;
  static double bottomClearance(TextScaler scaler) =>
      contentHeight(scaler) + 2 * inset + bottomMargin + 24;
}

class _CompactNavigation extends StatefulWidget {
  const _CompactNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.visible,
  });
  final int selectedIndex;
  final ValueListenable<bool> visible;
  final ValueChanged<int> onSelected;

  @override
  State<_CompactNavigation> createState() => _CompactNavigationState();
}

class _CompactNavigationState extends State<_CompactNavigation>
    with WidgetsBindingObserver {
  static const _accessibility = MethodChannel(
    'com.medyma.immortalwrt/navigation-accessibility',
  );
  bool? _touchExploration;
  bool _usesAndroidAccessibility = false;
  int _request = 0;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_android) {
      _usesAndroidAccessibility = true;
      _accessibility.setMethodCallHandler((call) async {
        if (call.method == 'touchExplorationChanged' &&
            call.arguments is bool) {
          _request++;
          _applyTouchExploration(call.arguments as bool);
        }
      });
      _loadTouchExploration();
    }
  }

  void _applyTouchExploration(bool value) {
    if (mounted && value != _touchExploration) {
      setState(() => _touchExploration = value);
    }
  }

  Future<void> _loadTouchExploration() async {
    final request = ++_request;
    try {
      final value = await _accessibility.invokeMethod<bool>(
        'getTouchExplorationEnabled',
      );
      if (mounted && request == _request && value != null) {
        _applyTouchExploration(value);
      }
    } on MissingPluginException {
      // Older hosts retain the framework accessibility fallback.
    } on PlatformException {
      // Keep navigation reachable when native state cannot be read.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_android && state == AppLifecycleState.resumed) {
      _loadTouchExploration();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    if (_usesAndroidAccessibility) _accessibility.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.visible,
    builder: (context, _) {
      // Android's generic accessibleNavigation flag can be set by node queries,
      // even without TalkBack. Prefer the actual touch-exploration state.
      final keepVisible =
          _touchExploration ?? MediaQuery.accessibleNavigationOf(context);
      final show = keepVisible || widget.visible.value;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _NavigationGeometry.duration;
      const labels = ['总览', '设备', 'Wi-Fi', '流量'];
      const icons = [
        Icons.home_outlined,
        Icons.devices_outlined,
        Icons.router_outlined,
        Icons.bar_chart_outlined,
      ];
      const selectedIcons = [
        Icons.home_rounded,
        Icons.devices_rounded,
        Icons.router_rounded,
        Icons.bar_chart_rounded,
      ];
      final scheme = Theme.of(context).colorScheme;
      return IgnorePointer(
        ignoring: !show,
        child: ExcludeFocus(
          excluding: !show,
          child: ExcludeSemantics(
            excluding: !show,
            child: AnimatedSlide(
              offset: show
                  ? Offset.zero
                  : const Offset(0, _NavigationGeometry.hiddenSlide),
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: duration,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _NavigationGeometry.horizontalMargin,
                      0,
                      _NavigationGeometry.horizontalMargin,
                      _NavigationGeometry.bottomMargin,
                    ),
                    child: RepaintBoundary(
                      child: _GlassSurface(
                        border: false,
                        radius: BorderRadius.circular(
                          _NavigationGeometry.radius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            _NavigationGeometry.inset,
                          ),
                          child: Row(
                            key: const ValueKey('compact-navigation'),
                            children: List.generate(4, (index) {
                              final selected = index == widget.selectedIndex;
                              return Expanded(
                                child: Semantics(
                                  label: labels[index],
                                  selected: selected,
                                  button: true,
                                  child: AnimatedContainer(
                                    duration: duration,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? scheme.primaryContainer.withValues(
                                              alpha: 0.85,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        _NavigationGeometry.selectedRadius,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: const StadiumBorder(),
                                        onTap: () => widget.onSelected(index),
                                        child: SizedBox(
                                          height:
                                              _NavigationGeometry.contentHeight(
                                                MediaQuery.textScalerOf(
                                                  context,
                                                ),
                                              ),
                                          child: ExcludeSemantics(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  selected
                                                      ? selectedIcons[index]
                                                      : icons[index],
                                                  size: 22,
                                                  color: selected
                                                      ? scheme
                                                            .onPrimaryContainer
                                                      : _mutedOf(context),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  labels[index],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize:
                                                        _NavigationGeometry
                                                            .labelSize,
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: selected
                                                        ? scheme
                                                              .onPrimaryContainer
                                                        : _mutedOf(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
