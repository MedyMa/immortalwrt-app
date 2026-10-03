part of '../main.dart';

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.visible,
    required this.scrolling,
  });
  final int selectedIndex;
  final ValueListenable<bool> visible;
  final ValueListenable<bool> scrolling;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([visible, scrolling]),
    builder: (context, _) {
      final show = visible.value || MediaQuery.accessibleNavigationOf(context);
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180);
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
              offset: show ? Offset.zero : const Offset(0, 1.4),
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: duration,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: RepaintBoundary(
                      child: _GlassSurface(
                        blur: !scrolling.value && show,
                        border: false,
                        radius: BorderRadius.circular(40),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
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
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: const StadiumBorder(),
                                        onTap: () => onSelected(index),
                                        child: SizedBox(
                                          height:
                                              52 +
                                              math.max(
                                                    0,
                                                    MediaQuery.textScalerOf(
                                                          context,
                                                        ).scale(11) -
                                                        11,
                                                  ) *
                                                  2,
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
                                                    fontSize: 11,
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
