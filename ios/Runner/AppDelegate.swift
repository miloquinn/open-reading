import Flutter
import UIKit
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer

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
@objc class AppDelegate: FlutterAppDelegate {
  private var readerImmersiveEnabled = false
  private lazy var readiumHttpClient: HTTPClient = DefaultHTTPClient()
  private lazy var readiumAssetRetriever = AssetRetriever(httpClient: readiumHttpClient)
  private lazy var readiumHttpServer: HTTPServer = GCDHTTPServer(assetRetriever: readiumAssetRetriever)
  private lazy var readiumPublicationOpener = PublicationOpener(
    parser: DefaultPublicationParser(
      httpClient: readiumHttpClient,
      assetRetriever: readiumAssetRetriever,
      pdfFactory: DefaultPDFDocumentFactory()
    ),
    contentProtections: []
  )
  private var readiumPresentedPublications: [ObjectIdentifier: Publication] = [:]

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

    GeneratedPluginRegistrant.register(with: self)

    let messenger: FlutterBinaryMessenger? =
      (window?.rootViewController as? FlutterViewController)?.binaryMessenger
      ?? self.registrar(forPlugin: "ReaderUIBridge")?.messenger()

    guard let messenger else {
      NSLog("Reader bridge init failed: binaryMessenger unavailable")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let iCloudChannel = FlutterMethodChannel(
      name: "com.niki.xxread/icloud",
      binaryMessenger: messenger
    )
    iCloudChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getICloudDocumentsPath":
        self?.getICloudDocumentsPath(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
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

    let readiumChannel = FlutterMethodChannel(
      name: "com.niki.xxread/readium",
      binaryMessenger: messenger
    )
    readiumChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else {
        result(false)
        return
      }
      switch call.method {
      case "isAvailable":
        result(true)
      case "openEpub":
        self.openEpubByReadium(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getICloudDocumentsPath(result: @escaping FlutterResult) {
    // nil 表示默认容器，需要目标已开启 iCloud Documents capability
    guard let iCloudContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      result(nil)
      return
    }

    let documentsURL = iCloudContainer.appendingPathComponent("Documents")
    do {
      try FileManager.default.createDirectory(
        at: documentsURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
      result(documentsURL.path)
    } catch {
      result(nil)
    }
  }

  private func openEpubByReadium(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let rawFilePath = args["filePath"] as? String
    else {
      NSLog("Readium openEpub invalid args")
      result(false)
      return
    }
    let title = (args["title"] as? String) ?? ""
    let normalizedInput = rawFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let fileURL = resolveLocalFileURL(from: normalizedInput) else {
      NSLog("Readium openEpub invalid file path: %@", normalizedInput)
      result(false)
      return
    }

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      NSLog("Readium openEpub file not found: %@", fileURL.path)
      result(false)
      return
    }

    Task { [weak self] in
      guard let self else {
        DispatchQueue.main.async { result(false) }
        return
      }
      do {
        guard let absoluteURL = FileURL(url: fileURL) else {
          NSLog("Readium openEpub failed to create FileURL: %@", fileURL.absoluteString)
          DispatchQueue.main.async { result(false) }
          return
        }
        let sender = self.topPresentedController()
        let asset = try await self.readiumAssetRetriever.retrieve(url: absoluteURL).get()
        let publication = try await self.readiumPublicationOpener.open(
          asset: asset,
          allowUserInteraction: false,
          sender: sender
        ).get()
        DispatchQueue.main.async {
          self.presentReadiumPublication(publication: publication, title: title, result: result)
        }
      } catch {
        NSLog("Readium openEpub failed: \(error.localizedDescription)")
        DispatchQueue.main.async { result(false) }
      }
    }
  }

  private func presentReadiumPublication(
    publication: Publication,
    title: String,
    result: @escaping FlutterResult
  ) {
    guard let presenter = topPresentedController() else {
      publication.close()
      result(false)
      return
    }

    do {
      let navigator = try EPUBNavigatorViewController(
        publication: publication,
        initialLocation: nil,
        httpServer: readiumHttpServer
      )
      if !title.isEmpty {
        navigator.navigationItem.title = title
      } else if let metadataTitle = publication.metadata.title {
        navigator.navigationItem.title = metadataTitle
      }

      let navController = UINavigationController(rootViewController: navigator)
      navController.modalPresentationStyle = UIModalPresentationStyle.fullScreen

      let key = ObjectIdentifier(navController)
      readiumPresentedPublications[key] = publication

      navigator.navigationItem.leftBarButtonItem = UIBarButtonItem(
        systemItem: .close,
        primaryAction: UIAction { [weak self, weak navController] _ in
          guard let navController else { return }
          self?.releaseReadiumPublication(for: navController)
          navController.dismiss(animated: true)
        }
      )

      presenter.present(navController, animated: true) {
        result(true)
      }
    } catch {
      publication.close()
      NSLog("Readium navigator failed: \(error.localizedDescription)")
      result(false)
    }
  }

  private func resolveLocalFileURL(from rawPath: String) -> URL? {
    if rawPath.isEmpty {
      return nil
    }
    if rawPath.hasPrefix("file://"), let uri = URL(string: rawPath), uri.isFileURL {
      return uri
    }
    return URL(fileURLWithPath: rawPath)
  }

  private func releaseReadiumPublication(for navController: UINavigationController) {
    let key = ObjectIdentifier(navController)
    guard let publication = readiumPresentedPublications.removeValue(forKey: key) else {
      return
    }
    publication.close()
  }

  private func topPresentedController() -> UIViewController? {
    let root: UIViewController?
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
      let scene = scenes.first(where: { $0.activationState == .foregroundActive })
        ?? scenes.first(where: { $0.activationState == .foregroundInactive })
        ?? scenes.first
      let keyWindow = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
      root = keyWindow?.rootViewController
    } else {
      root = window?.rootViewController
    }
    var top = root
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
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
