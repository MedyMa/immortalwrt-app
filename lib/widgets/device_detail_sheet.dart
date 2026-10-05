part of '../main.dart';

class _DeviceDetailSheet extends StatefulWidget {
  const _DeviceDetailSheet({required this.row, required this.identity});
  final _DeviceRow row;
  final DeviceIdentity identity;

  @override
  State<_DeviceDetailSheet> createState() => _DeviceDetailSheetState();
}

class _DeviceDetailSheetState extends State<_DeviceDetailSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final identity = widget.identity;
    final apple = Theme.of(context).platform == TargetPlatform.iOS;
    final closeIcon = _AppleSymbol(
      'xmark',
      fallback: Icons.close_rounded,
      size: 18,
      color: _mutedOf(context),
    );
    final close = apple
        ? CupertinoButton(
            key: const ValueKey('device-detail-close'),
            onPressed: () => Navigator.pop(context),
            child: Semantics(label: '关闭', child: closeIcon),
          )
        : IconButton(
            key: const ValueKey('device-detail-close'),
            onPressed: () => Navigator.pop(context),
            tooltip: '关闭',
            icon: closeIcon,
          );
    final disclosure = Row(
      children: [
        Expanded(
          child: Text(
            '识别依据',
            style: TextStyle(fontSize: 12, color: _mutedOf(context)),
          ),
        ),
        _AppleSymbol(
          _expanded ? 'chevron.up' : 'chevron.down',
          fallback: _expanded
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          size: 12,
          color: _mutedOf(context),
        ),
      ],
    );
    void toggle() => setState(() => _expanded = !_expanded);
    final toggleButton = apple
        ? CupertinoButton(
            key: const ValueKey('device-evidence-toggle'),
            onPressed: toggle,
            child: disclosure,
          )
        : TextButton(
            key: const ValueKey('device-evidence-toggle'),
            onPressed: toggle,
            child: disclosure,
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: _IosGlassSurface(
        radius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _mutedOf(context).withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeviceIcon(identity: identity, color: _blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            row.name.isEmpty ||
                                    row.name == row.ip ||
                                    row.name == '*'
                                ? '未命名设备'
                                : row.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _inkOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(identity.label, style: _bodyStyle(context)),
                        ],
                      ),
                    ),
                    close,
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本次会话流量', style: _bodyStyle(context)),
                      const SizedBox(height: 6),
                      Text(
                        row.bytes == null ? '—' : formatBytes(row.bytes!),
                        style: _figureStyle(context, size: 28),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final address in row.addresses) ...[
                  _DeviceDetailLine(
                    label: address.contains(':') ? 'IPv6 地址' : 'IPv4 地址',
                    value: address,
                    copyValue: true,
                  ),
                  const _Hairline(),
                ],
                for (final entry in <(String, String)>[
                  ('MAC 地址', row.mac.isEmpty ? '未提供' : row.mac),
                  (
                    '记录来源',
                    [
                      if (row.hasLease) 'DHCP 租约',
                      if (row.hasHint) '地址归属提示',
                      if (row.hasTraffic) '流量记录',
                    ].join(' · '),
                  ),
                ]) ...[
                  _DeviceDetailLine(label: entry.$1, value: entry.$2),
                  const _Hairline(),
                ],
                const SizedBox(height: 8),
                Semantics(expanded: _expanded, child: toggleButton),
                if (_expanded)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(identity.evidence, style: _bodyStyle(context)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceDetailLine extends StatelessWidget {
  const _DeviceDetailLine({
    required this.label,
    required this.value,
    this.copyValue = false,
  });
  final String label;
  final String value;
  final bool copyValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(13) > 18;
        final title = Text(label, style: _bodyStyle(context));
        final content = SelectableText(
          value,
          textAlign: stacked ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: _inkOf(context),
          ),
        );
        final copy = IconButton(
          key: ValueKey('copy-address-$value'),
          tooltip: '复制 $label',
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          icon: _AppleSymbol(
            'doc.on.doc',
            fallback: Icons.copy_rounded,
            size: 17,
            color: _mutedOf(context),
          ),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: title),
                      if (copyValue) copy,
                    ],
                  ),
                  const SizedBox(height: 6),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 84, child: title),
                  Expanded(child: content),
                  if (copyValue) copy,
                ],
              );
      },
    ),
  );
}
