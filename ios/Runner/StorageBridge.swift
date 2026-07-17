import Flutter
import Foundation

final class StorageBridge {
  private static let channelName = "com.niki.xxread/storage"
  private static let containerIdentifier = "iCloud.com.niki.xxread"

  private let channel: FlutterMethodChannel
  private let fileManager: FileManager

  init(messenger: FlutterBinaryMessenger, fileManager: FileManager = .default) {
    self.fileManager = fileManager
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getICloudStatus":
      perform(result: result) { [self] in
        guard let documentsURL = try iCloudDocumentsURL(createIfNeeded: true) else {
          return ["available": false]
        }
        return [
          "available": true,
          "documentsPath": documentsURL.path,
          "containerIdentifier": Self.containerIdentifier,
        ]
      }
    case "listICloudDocuments":
      perform(result: result) { [self] in
        try listICloudDocuments()
      }
    case "materializeICloudDocument":
      guard let arguments = call.arguments as? [String: Any],
            let locator = arguments["locator"] as? String,
            let destinationPath = arguments["destinationPath"] as? String else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "locator and destinationPath are required",
            details: nil
          )
        )
        return
      }
      perform(result: result) { [self] in
        try materializeICloudDocument(
          locator: locator,
          destinationPath: destinationPath
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func perform(
    result: @escaping FlutterResult,
    operation: @escaping () throws -> Any
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "storage_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func iCloudDocumentsURL(createIfNeeded: Bool) throws -> URL? {
    guard let containerURL = fileManager.url(
      forUbiquityContainerIdentifier: Self.containerIdentifier
    ) else {
      return nil
    }
    let documentsURL = containerURL.appendingPathComponent(
      "Documents",
      isDirectory: true
    ).appendingPathComponent("books", isDirectory: true)
    if createIfNeeded && !fileManager.fileExists(atPath: documentsURL.path) {
      try fileManager.createDirectory(
        at: documentsURL,
        withIntermediateDirectories: true
      )
    }
    return documentsURL
  }

  private func listICloudDocuments() throws -> [[String: Any]] {
    guard let documentsURL = try iCloudDocumentsURL(createIfNeeded: true) else {
      return []
    }
    let resourceKeys: [URLResourceKey] = [
      .isDirectoryKey,
      .fileSizeKey,
      .contentModificationDateKey,
      .isUbiquitousItemKey,
      .ubiquitousItemDownloadingStatusKey,
    ]
    guard let enumerator = fileManager.enumerator(
      at: documentsURL,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var rows: [[String: Any]] = []
    for case let fileURL as URL in enumerator {
      let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
      if values.isDirectory == true { continue }
      let locator = try relativeLocator(for: fileURL, root: documentsURL)
      var row: [String: Any] = [
        "locator": locator,
        "displayName": fileURL.lastPathComponent,
        "extension": fileURL.pathExtension.lowercased(),
        "downloaded": values.ubiquitousItemDownloadingStatus == .current,
      ]
      if let size = values.fileSize { row["sizeBytes"] = size }
      if let modified = values.contentModificationDate {
        row["modifiedTime"] = Int(modified.timeIntervalSince1970 * 1000)
      }
      rows.append(row)
    }
    return rows
  }

  private func materializeICloudDocument(
    locator: String,
    destinationPath: String
  ) throws -> String {
    guard let documentsURL = try iCloudDocumentsURL(createIfNeeded: false) else {
      throw StorageBridgeError.iCloudUnavailable
    }
    let sourceURL = try sourceURL(for: locator, root: documentsURL)
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw StorageBridgeError.sourceMissing
    }

    let values = try sourceURL.resourceValues(forKeys: [.isUbiquitousItemKey])
    if values.isUbiquitousItem == true {
      try fileManager.startDownloadingUbiquitousItem(at: sourceURL)
      try waitUntilDownloaded(sourceURL)
    }

    let destinationURL = URL(fileURLWithPath: destinationPath)
    try fileManager.createDirectory(
      at: destinationURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var copyError: Error?
    coordinator.coordinate(
      readingItemAt: sourceURL,
      options: [.withoutChanges],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
      } catch {
        copyError = error
      }
    }
    if let coordinationError {
      try? fileManager.removeItem(at: destinationURL)
      throw coordinationError
    }
    if let copyError {
      try? fileManager.removeItem(at: destinationURL)
      throw copyError
    }
    return destinationURL.path
  }

  private func waitUntilDownloaded(_ url: URL) throws {
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      let values = try url.resourceValues(
        forKeys: [.ubiquitousItemDownloadingStatusKey]
      )
      if values.ubiquitousItemDownloadingStatus == .current { return }
      Thread.sleep(forTimeInterval: 0.2)
    }
    throw StorageBridgeError.downloadTimedOut
  }

  private func sourceURL(for locator: String, root: URL) throws -> URL {
    try Self.validatedSourceURL(locator: locator, root: root)
  }

  static func validatedSourceURL(locator: String, root: URL) throws -> URL {
    let components = locator.split(separator: "/", omittingEmptySubsequences: false)
    guard !locator.isEmpty,
          !locator.hasPrefix("/"),
          !components.contains(".."),
          !components.contains(".") else {
      throw StorageBridgeError.invalidLocator
    }
    let candidate = root.appendingPathComponent(locator).standardizedFileURL
    let rootPath = root.standardizedFileURL.path + "/"
    guard candidate.path.hasPrefix(rootPath) else {
      throw StorageBridgeError.invalidLocator
    }
    return candidate
  }

  private func relativeLocator(for fileURL: URL, root: URL) throws -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let filePath = fileURL.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath) else {
      throw StorageBridgeError.invalidLocator
    }
    return String(filePath.dropFirst(rootPath.count))
  }
}

private enum StorageBridgeError: LocalizedError {
  case iCloudUnavailable
  case sourceMissing
  case invalidLocator
  case downloadTimedOut

  var errorDescription: String? {
    switch self {
    case .iCloudUnavailable:
      return "iCloud Documents is unavailable"
    case .sourceMissing:
      return "The selected iCloud file no longer exists"
    case .invalidLocator:
      return "The iCloud document locator is invalid"
    case .downloadTimedOut:
      return "Timed out while downloading the iCloud document"
    }
  }
}
