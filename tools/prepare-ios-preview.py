from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / "lib/main.dart"
s = p.read_text(encoding="utf-8")
s = s.replace("import 'models/router_models.dart';", "import 'models/router_models.dart';\nimport '../tools/ios_preview_fixture.dart';")
s = s.replace("    _restore();", "    _loadPreview();", 1)
a = s.index("  Future<void> _restore()")
s = s[:a] + """  Future<void> _loadPreview() async {
    final tab = await const MethodChannel('com.medyma.immortalwrt/preview').invokeMethod<int>('tab') ?? 0;
    if (!mounted) return;
    setState(() { _snapshot = previewSnapshot(); _tab = tab; });
  }

""" + s[a:]
p.write_text(s, encoding="utf-8")
p = root / "ios/Runner/AppDelegate.swift"
s = p.read_text(encoding="utf-8")
s = s.replace("  func didInitializeImplicitFlutterEngine", "  private var previewChannel: FlutterMethodChannel?\n\n  func didInitializeImplicitFlutterEngine", 1)
s = s.replace('    registrar.register(SystemTabBarFactory', """    previewChannel = FlutterMethodChannel(name: "com.medyma.immortalwrt/preview", binaryMessenger: registrar.messenger())
    previewChannel?.setMethodCallHandler { call, result in
      guard call.method == "tab" else { result(FlutterMethodNotImplemented); return }
      result(Int(ProcessInfo.processInfo.environment["IOS_PREVIEW_TAB"] ?? "0") ?? 0)
    }
    registrar.register(SystemTabBarFactory""", 1)
p.write_text(s, encoding="utf-8")
