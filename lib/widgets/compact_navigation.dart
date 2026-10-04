part of '../main.dart';

/// Shared compact chrome dimensions; safe-area padding is added separately.
abstract final class _NavigationGeometry {
  static const radius = 28.0;
  static const height = 72.0;
  static const inset = 4.0;
  static const horizontalMargin = 12.0;
  static const bottomMargin = 8.0;
  static const labelSize = 11.0;
  static const hiddenSlide = 1.4;
  static const dragThreshold = 12.0;
  static const topTolerance = 0.5;
  static const railBreakpoint = 700.0;
  static const blurSigma = 18.0;
  static const duration = Duration(milliseconds: 180);

  static double contentHeight(TextScaler scaler) =>
      height - 2 * inset + math.max(0, scaler.scale(labelSize) - labelSize) * 2;
  static double bottomClearance(TextScaler scaler) =>
      contentHeight(scaler) + 2 * inset + bottomMargin + 24;
}

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.visible,
  });
  final int selectedIndex;
  final ValueListenable<bool> visible;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: visible,
    builder: (context, _) {
      // TalkBack users must be able to switch pages without scrolling to top.
      final show = MediaQuery.accessibleNavigationOf(context) || visible.value;
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
                              final selected = index == selectedIndex;
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
                                        _NavigationGeometry.radius -
                                            _NavigationGeometry.inset,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: const StadiumBorder(),
                                        onTap: () => onSelected(index),
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
