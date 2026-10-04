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
    registrar.register(SystemGlassFactory(), withId: "com.medyma.immortalwrt/glass-surface")
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

private class TabBarHost: UIView {
  let controller: UITabBarController

  init(frame: CGRect, controller: UITabBarController) {
    self.controller = controller
    super.init(frame: frame)
    backgroundColor = .clear
    controller.view.backgroundColor = .clear
    addSubview(controller.view)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func layoutSubviews() {
    super.layoutSubviews()
    controller.view.bounds = CGRect(origin: .zero, size: bounds.size)
    controller.view.center = CGPoint(x: bounds.midX, y: bounds.midY)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      controller.willMove(toParent: nil)
      controller.view.removeFromSuperview()
      controller.removeFromParent()
      return
    }
    if controller.view.superview == nil { addSubview(controller.view) }
    guard controller.parent == nil else { return }
    var responder: UIResponder? = superview
    while let current = responder {
      if let parent = current as? UIViewController {
        parent.addChild(controller)
        controller.didMove(toParent: parent)
        break
      }
      responder = current.next
    }
  }
}

private class SystemTabBarView: NSObject, FlutterPlatformView, UITabBarControllerDelegate {
  private let controller: UITabBarController
  private let host: TabBarHost
  private let channel: FlutterMethodChannel
  private var visible = true

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    controller = UITabBarController()
    host = TabBarHost(frame: frame, controller: controller)
    channel = FlutterMethodChannel(
      name: "com.medyma.immortalwrt/navigation/\(viewId)",
      binaryMessenger: messenger)
    super.init()

    let titles = ["总览", "设备", "Wi-Fi", "流量"]
    let symbols = ["house", "desktopcomputer", "wifi", "chart.bar"]
    let pages = (0..<titles.count).map { index in
      let page = UIViewController()
      page.view.backgroundColor = .clear
      page.tabBarItem = UITabBarItem(title: titles[index],
                                    image: UIImage(systemName: symbols[index]), tag: index)
      return page
    }
    controller.setViewControllers(pages, animated: false)
    controller.delegate = self
    controller.tabBar.isTranslucent = true
    // Flutter supplies the scroll direction. Native minimization observes
    // UIScrollView, so leave it off and animate the actual system view instead.
    if #available(iOS 26.0, *) { controller.tabBarMinimizeBehavior = .never }
    let selected = (args as? [String: Any])?["selectedIndex"] as? Int ?? 0
    if pages.indices.contains(selected) { controller.selectedIndex = selected }
    visible = (args as? [String: Any])?["visible"] as? Bool ?? true
    host.isHidden = !visible
    host.isUserInteractionEnabled = visible
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      if call.method == "setVisible", let show = call.arguments as? Bool {
        self.setVisible(show)
        result(nil)
        return
      }
      guard call.method == "setTab", let index = call.arguments as? Int,
            self.controller.viewControllers?.indices.contains(index) == true else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.controller.selectedIndex = index
      result(nil)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  func view() -> UIView { host }

  private func setVisible(_ show: Bool) {
    guard visible != show else { return }
    visible = show
    host.isHidden = false
    host.isUserInteractionEnabled = show
    host.accessibilityElementsHidden = !show
    UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.22,
                   delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
      self.controller.view.transform = show ? .identity :
        CGAffineTransform(translationX: 0, y: self.host.bounds.height + 24)
    } completion: { [weak self] _ in
      guard let self else { return }
      self.host.isHidden = !self.visible
    }
  }

  func tabBarController(_ tabBarController: UITabBarController,
                        didSelect viewController: UIViewController) {
    channel.invokeMethod("selectTab", arguments: tabBarController.selectedIndex)
  }
}

private class SystemGlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    SystemGlassView(frame: frame, args: args)
  }
}

private class SystemGlassView: NSObject, FlutterPlatformView {
  private let glass: UIVisualEffectView
  init(frame: CGRect, args: Any?) {
    let sheet = (args as? [String: Any])?["sheet"] as? Bool ?? false
    let effect: UIVisualEffect
    if #available(iOS 26.0, *), sheet {
      effect = UIGlassEffect(style: .regular)
    } else {
      effect = UIBlurEffect(style: .systemMaterial)
    }
    glass = UIVisualEffectView(effect: effect)
    super.init()
    glass.frame = frame
    if sheet {
      glass.layer.cornerRadius = 28
      glass.layer.cornerCurve = .continuous
      glass.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      glass.clipsToBounds = true
    }
    glass.isUserInteractionEnabled = false
    glass.accessibilityElementsHidden = true
  }
  func view() -> UIView { glass }
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
