"""Inject fixtures and a rendered-page handshake in the disposable CI checkout."""
from pathlib import Path


def replace_once(source, anchor, replacement, label):
    count = source.count(anchor)
    if count != 1:
        raise ValueError(f"{label}: expected one anchor, found {count}")
    return source.replace(anchor, replacement, 1)


def inject(source, anchor, body, label, trailing=""):
    if source.count(anchor) != 1:
        raise ValueError(f"{label}: expected one anchor, found {source.count(anchor)}")
    start, end = f"// IOS_PREVIEW_BEGIN {label}", f"// IOS_PREVIEW_END {label}"
    block = f"{start}\n{body}\n{end}\n{trailing}"
    if start in source or end in source:
        if source.count(block) != 1 or source.count(start) != 1 or source.count(end) != 1:
            raise ValueError(f"{label}: partial or outdated preview injection")
        return source
    return replace_once(source, anchor, block + anchor, label)


DART_LOADER = """  Future<void> _loadPreview() async {
    const channel = MethodChannel('com.medyma.immortalwrt/preview');
    final config = await channel.invokeMapMethod<String, dynamic>('configuration');
    final tab = config!['tab'] as int;
    if (tab < 0 || tab > 5) throw StateError('Invalid preview tab');
    if (!mounted) return;
    setState(() { _snapshot = previewSnapshot(); _tab = tab == 4 ? 1 : tab == 5 ? 0 : tab; });
    // Wait for the fixture page to be painted, including its native views.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (tab == 5) {
      ScrollableState? scroll;
      void visit(Element element) {
        if (scroll != null) return;
        if (element is StatefulElement && element.state is ScrollableState) {
          scroll = element.state as ScrollableState;
          return;
        }
        element.visitChildren(visit);
      }
      (context as Element).visitChildren(visit);
      if (scroll == null || !scroll!.position.hasContentDimensions) {
        throw StateError('Preview scrollable is unavailable');
      }
      scroll!.position.jumpTo(300.0.clamp(0.0, scroll!.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (tab == 4) {
      final row = _DeviceIndex.of(_snapshot!).rows.first;
      _showDeviceDetails(context, row, DeviceIdentity.fromName(row.name));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    await channel.invokeMethod<void>('ready', {
      'nonce': config['nonce'],
      'tab': tab,
      'appearance': Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light',
    });
  }
"""

SWIFT_CHANNEL = """    previewChannel = FlutterMethodChannel(name: "com.medyma.immortalwrt/preview",
                                          binaryMessenger: registrar.messenger())
    previewChannel?.setMethodCallHandler { call, result in
      let env = ProcessInfo.processInfo.environment
      switch call.method {
      case "configuration":
        result(["tab": Int(env["IOS_PREVIEW_TAB"] ?? "") ?? -1,
                "nonce": env["IOS_PREVIEW_NONCE"] ?? ""])
      case "ready":
        guard let payload = call.arguments as? [String: Any],
              payload["nonce"] as? String == env["IOS_PREVIEW_NONCE"],
              payload["tab"] as? Int == Int(env["IOS_PREVIEW_TAB"] ?? ""),
              payload["appearance"] as? String == env["IOS_PREVIEW_APPEARANCE"] else {
          result(FlutterError(code: "preview_mismatch", message: "Unexpected preview page", details: nil))
          return
        }
        do {
          let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          let data = try JSONSerialization.data(withJSONObject: payload)
          try data.write(to: directory.appendingPathComponent("ios-preview-ready.json"), options: .atomic)
          result(nil)
        } catch {
          result(FlutterError(code: "preview_write", message: error.localizedDescription, details: nil))
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
"""


def prepare(root):
    dart_path = root / "lib/main.dart"
    swift_path = root / "ios/Runner/AppDelegate.swift"
    dart = dart_path.read_text(encoding="utf-8")
    swift = swift_path.read_text(encoding="utf-8")
    fixture = (root / "tools/ios_preview_fixture.dart").read_text(encoding="utf-8")
    dart = inject(dart, "import 'models/router_models.dart';",
                  "import 'ios_preview_fixture.dart';", "fixture-import")
    dart = inject(dart, "  Future<void> _restore()", DART_LOADER, "loader",
                  trailing="  // ignore: unused_element\n")
    original = "    _restore();"
    replacement = "    _loadPreview(); // IOS_PREVIEW_INIT"
    if "IOS_PREVIEW_INIT" in dart:
        if dart.count(replacement) != 1 or original in dart:
            raise ValueError("preview init: partial or ambiguous injection")
    else:
        dart = replace_once(dart, original, replacement, "preview init")
    swift = inject(swift, "  func didInitializeImplicitFlutterEngine",
                   "  private var previewChannel: FlutterMethodChannel?", "channel-property")
    swift = inject(swift, "    registrar.register(SystemTabBarFactory",
                   SWIFT_CHANNEL, "channel-handler")
    # Validate both files and the fixture before making any writes.
    (root / "lib/ios_preview_fixture.dart").write_text(fixture, encoding="utf-8")
    dart_path.write_text(dart, encoding="utf-8")
    swift_path.write_text(swift, encoding="utf-8")


if __name__ == "__main__":
    prepare(Path(__file__).resolve().parents[1])
