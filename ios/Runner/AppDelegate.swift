import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemTabBar") else { return }
    registrar.register(SystemTabBarFactory(messenger: registrar.messenger()),
                       withId: "com.medyma.immortalwrt/system-tab-bar")
    registrar.register(SystemSettingsFactory(messenger: registrar.messenger()),
                       withId: "com.medyma.immortalwrt/settings-button")
  }
}

private class SystemSettingsFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    SystemSettingsView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

private class SystemSettingsView: NSObject, FlutterPlatformView {
  private let button: UIButton
  private let channel: FlutterMethodChannel
  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    button = UIButton(frame: frame)
    channel = FlutterMethodChannel(name: "com.medyma.immortalwrt/settings/\(viewId)",
                                   binaryMessenger: messenger)
    super.init()
    var configuration: UIButton.Configuration
    if #available(iOS 26.0, *) {
      configuration = .glass()
    } else {
      configuration = .plain()
    }
    configuration.image = UIImage(systemName: "gearshape")
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 22)
    configuration.baseForegroundColor = .label
    configuration.cornerStyle = .capsule
    button.configuration = configuration
    button.accessibilityLabel = "连接设置"
    button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
  }
  func view() -> UIView { button }
  @objc private func openSettings() {
    channel.invokeMethod("openSettings", arguments: nil)
  }
}

private class SystemTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return SystemTabBarView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private class SystemTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    tabBar = UITabBar(frame: frame)
    channel = FlutterMethodChannel(
      name: "com.medyma.immortalwrt/navigation/\(viewId)",
      binaryMessenger: messenger)
    super.init()

    let titles = ["总览", "设备", "Wi-Fi", "流量"]
    let symbols = ["house", "desktopcomputer", "wifi", "chart.bar"]
    tabBar.items = (0..<titles.count).map { index in
      UITabBarItem(title: titles[index],
                   image: UIImage(systemName: symbols[index]), tag: index)
    }
    tabBar.delegate = self
    tabBar.isTranslucent = true
    let selected = (args as? [String: Any])?["selectedIndex"] as? Int ?? 0
    if let items = tabBar.items, items.indices.contains(selected) {
      tabBar.selectedItem = items[selected]
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setTab", let index = call.arguments as? Int,
            let items = self?.tabBar.items, items.indices.contains(index) else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.tabBar.selectedItem = items[index]
      result(nil)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  func view() -> UIView { tabBar }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("selectTab", arguments: item.tag)
  }
}
