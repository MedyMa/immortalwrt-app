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
    registrar.register(SystemActionFactory(messenger: registrar.messenger()),
                       withId: "com.medyma.immortalwrt/action-button")
    registrar.register(SystemSymbolFactory(), withId: "com.medyma.immortalwrt/symbol")
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

private class SystemActionFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SystemActionView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}

private class SystemActionView: NSObject, FlutterPlatformView {
  private let button: UIButton
  private let channel: FlutterMethodChannel
  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    button = UIButton(frame: frame)
    channel = FlutterMethodChannel(name: "com.medyma.immortalwrt/action/\(viewId)", binaryMessenger: messenger)
    super.init()
    let data = args as? [String: Any] ?? [:]
    let prominent = data["prominent"] as? Bool ?? true
    var config: UIButton.Configuration
    if #available(iOS 26.0, *) { config = prominent ? .prominentGlass() : .glass() }
    else { config = prominent ? .filled() : .plain() }
    config.title = data["title"] as? String
    if let symbol = data["symbol"] as? String { config.image = UIImage(systemName: symbol) }
    config.imagePadding = 8
    config.cornerStyle = .capsule
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
    config.baseForegroundColor = prominent ? .white : .systemRed
    config.baseBackgroundColor = prominent ? .systemBlue : nil
    button.configuration = config
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.accessibilityLabel = config.title
    button.addTarget(self, action: #selector(activate), for: .touchUpInside)
  }
  func view() -> UIView { button }
  @objc private func activate() { channel.invokeMethod("activate", arguments: nil) }
}

private class SystemSymbolFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SystemSymbolView(frame: frame, args: args)
  }
}

private class SystemSymbolView: NSObject, FlutterPlatformView {
  private let imageView: UIImageView
  init(frame: CGRect, args: Any?) {
    imageView = UIImageView(frame: frame)
    super.init()
    let data = args as? [String: Any] ?? [:]
    let size = data["size"] as? Double ?? 18
    imageView.image = UIImage(systemName: data["name"] as? String ?? "chevron.right",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .medium))
    imageView.contentMode = .scaleAspectFit
    if let argb = data["color"] as? NSNumber {
      let n = argb.uint32Value
      imageView.tintColor = UIColor(red: CGFloat((n >> 16) & 255) / 255,
                                    green: CGFloat((n >> 8) & 255) / 255,
                                    blue: CGFloat(n & 255) / 255, alpha: CGFloat(n >> 24) / 255)
    } else { imageView.tintColor = .label }
    imageView.isAccessibilityElement = false
  }
  func view() -> UIView { imageView }
}
