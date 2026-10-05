part of '../main.dart';

/// Refresh follows each platform's scroll interaction and indicator style.
class _PlatformRefreshable extends StatelessWidget {
  const _PlatformRefreshable({
    required this.onRefresh,
    required this.padding,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CustomScrollView(
        key: const ValueKey('router-page-scroll'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            builder:
                (
                  context,
                  state,
                  pulledExtent,
                  triggerDistance,
                  indicatorExtent,
                ) => Transform.translate(
                  offset: Offset(0, MediaQuery.viewPaddingOf(context).top),
                  child: CupertinoSliverRefreshControl.buildRefreshIndicator(
                    context,
                    state,
                    pulledExtent,
                    triggerDistance,
                    indicatorExtent,
                  ),
                ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              padding.bottom,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      );
    }
    return RefreshIndicator(
      edgeOffset: MediaQuery.viewPaddingOf(context).top,
      onRefresh: onRefresh,
      color: _blue,
      child: ListView(
        key: const ValueKey('router-page-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      ),
    );
  }
}
