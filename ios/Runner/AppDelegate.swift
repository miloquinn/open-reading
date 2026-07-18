import Flutter
import UIKit

@objc(ReaderFlutterViewController) class ReaderFlutterViewController: FlutterViewController {
  private var readerImmersiveEnabled = false {
    didSet {
      if oldValue != readerImmersiveEnabled {
        refreshImmersiveUI()
      }
    }
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    readerImmersiveEnabled
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    readerImmersiveEnabled ? .all : []
  }

  @objc func setReaderImmersiveEnabled(_ enabled: Bool) {
    readerImmersiveEnabled = enabled
    if enabled {
      refreshImmersiveUI()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if readerImmersiveEnabled {
      refreshImmersiveUI()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if readerImmersiveEnabled {
      refreshImmersiveUI()
    }
  }

  private func refreshImmersiveUI() {
    setNeedsUpdateOfHomeIndicatorAutoHidden()
    setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  private var readerImmersiveEnabled = false
  private var storageBridge: StorageBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 设置状态栏样式为深色内容（适合浅色背景）
    if #available(iOS 13.0, *) {
      UIApplication.shared.statusBarStyle = .darkContent
    } else {
      UIApplication.shared.statusBarStyle = .default
    }

    pluginRegistrant = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)

    guard let messenger = registry.registrar(forPlugin: "ReaderUIBridge")?.messenger() else {
      NSLog("Reader bridge init failed: binaryMessenger unavailable")
      return
    }

    let readerUIChannel = FlutterMethodChannel(
      name: "com.niki.xxread/reader_ui",
      binaryMessenger: messenger
    )
    readerUIChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setReaderImmersive":
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
          result(
            FlutterError(
              code: "invalid_args",
              message: "expected {enabled: bool}",
              details: nil
            )
          )
          return
        }
        self?.readerImmersiveEnabled = enabled
        self?.applyReaderImmersiveIfPossible()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let readerStatusChannel = FlutterMethodChannel(
      name: "com.niki.xxread/reader_status",
      binaryMessenger: messenger
    )
    readerStatusChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getBatteryStatus":
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else {
          result(nil)
          return
        }
        let state = UIDevice.current.batteryState
        result([
          "level": Int((level * 100).rounded()),
          "charging": state == .charging || state == .full,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    storageBridge = StorageBridge(messenger: messenger)

  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    applyReaderImmersiveIfPossible()
  }

  private func applyReaderImmersiveIfPossible() {
    guard let controller = currentReaderController() else { return }
    controller.setReaderImmersiveEnabled(readerImmersiveEnabled)
  }

  private func currentReaderController() -> ReaderFlutterViewController? {
    if #available(iOS 13.0, *) {
      for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
        let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        if let found = findReaderController(in: keyWindow?.rootViewController) {
          return found
        }
      }
      return nil
    }
    return findReaderController(in: window?.rootViewController)
  }

  private func findReaderController(in viewController: UIViewController?) -> ReaderFlutterViewController? {
    guard let viewController else { return nil }
    if let reader = viewController as? ReaderFlutterViewController {
      return reader
    }
    if let presented = viewController.presentedViewController,
       let found = findReaderController(in: presented) {
      return found
    }
    if let nav = viewController as? UINavigationController {
      for vc in nav.viewControllers {
        if let found = findReaderController(in: vc) {
          return found
        }
      }
    }
    if let tab = viewController as? UITabBarController {
      for vc in tab.viewControllers ?? [] {
        if let found = findReaderController(in: vc) {
          return found
        }
      }
    }
    for child in viewController.children {
      if let found = findReaderController(in: child) {
        return found
      }
    }
    return nil
  }
}
