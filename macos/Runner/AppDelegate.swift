import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static let incomingChannelName = "com.niki.xxread/incoming_books"
  private static let maximumIncomingBookBytes: UInt64 = 100 * 1024 * 1024
  private static let maximumIncomingRequestBytes: UInt64 = 500 * 1024 * 1024
  private static let maximumIncomingItems = 10
  private static let requestManifestName = "request.json"

  private let incomingQueue = DispatchQueue(label: "com.niki.xxread.incoming-books")
  private var incomingChannel: FlutterMethodChannel?
  private var incomingRequests: [[String: Any]] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    incomingRequests = incomingQueue.sync { loadPersistedRequests() }
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: Self.incomingChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "bridge_unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "getInitialIncomingBooks":
        result(self.incomingRequests)
      case "completeIncomingRequest":
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String else {
          result(FlutterError(code: "invalid_args", message: "requestId is required", details: nil))
          return
        }
        let deleteFiles = arguments["deleteFiles"] as? Bool ?? true
        result(self.completeIncomingRequest(requestId: requestId, deleteFiles: deleteFiles))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    incomingChannel = channel
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    guard !filenames.isEmpty else {
      sender.reply(toOpenOrPrint: .failure)
      return
    }
    incomingQueue.async { [weak self] in
      guard let self else { return }
      do {
        let request = try self.materializeIncomingFiles(filenames)
        DispatchQueue.main.async {
          self.deliverIncomingRequest(request)
          sender.reply(toOpenOrPrint: .success)
        }
      } catch {
        NSLog("Incoming book open failed: %@", String(describing: error))
        DispatchQueue.main.async {
          sender.reply(toOpenOrPrint: .failure)
        }
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func materializeIncomingFiles(_ filenames: [String]) throws -> [String: Any] {
    let sourceURLs = filenames
      .map { URL(fileURLWithPath: $0).standardizedFileURL }
      .filter { supportedExtension($0.pathExtension) }
    guard sourceURLs.count <= Self.maximumIncomingItems else {
      throw IncomingBookError.tooManyFiles
    }
    let requestId = UUID().uuidString.lowercased()
    let requestDirectory = try incomingRoot().appendingPathComponent(requestId, isDirectory: true)
    try FileManager.default.createDirectory(
      at: requestDirectory,
      withIntermediateDirectories: true
    )

    var items: [[String: Any]] = []
    var aggregateBytes: UInt64 = 0
    do {
      for sourceURL in sourceURLs {
        let values = try sourceURL.resourceValues(forKeys: [
          .isRegularFileKey,
          .fileSizeKey,
          .contentModificationDateKey,
        ])
        guard values.isRegularFile == true else { continue }
        let size = UInt64(values.fileSize ?? 0)
        guard size <= Self.maximumIncomingBookBytes else { continue }
        guard size <= Self.maximumIncomingRequestBytes - aggregateBytes else {
          throw IncomingBookError.aggregateTooLarge
        }
        let fileName = safeFileName(sourceURL.lastPathComponent)
        let destinationURL = uniqueDestination(in: requestDirectory, fileName: fileName)
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
          if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let copiedBytes = try coordinatedCopy(
          from: sourceURL,
          to: destinationURL,
          aggregateBefore: aggregateBytes
        )
        aggregateBytes += copiedBytes
        var item: [String: Any] = [
          "id": UUID().uuidString.lowercased(),
          "displayName": fileName,
          "localPath": destinationURL.path,
          "mimeType": mimeType(for: destinationURL.pathExtension),
          "sizeBytes": Int(copiedBytes),
        ]
        if let modified = values.contentModificationDate {
          item["modifiedTime"] = Int(modified.timeIntervalSince1970 * 1000)
        }
        items.append(item)
      }
      guard !items.isEmpty else { throw IncomingBookError.noSupportedFiles }
      let request: [String: Any] = [
        "requestId": requestId,
        "action": "open",
        "items": items,
      ]
      try persistRequest(request, in: requestDirectory)
      return request
    } catch {
      try? FileManager.default.removeItem(at: requestDirectory)
      throw error
    }
  }

  private func coordinatedCopy(
    from sourceURL: URL,
    to destinationURL: URL,
    aggregateBefore: UInt64
  ) throws -> UInt64 {
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var copyError: Error?
    var copiedBytes: UInt64 = 0
    coordinator.coordinate(
      readingItemAt: sourceURL,
      options: [.withoutChanges],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let input = try FileHandle(forReadingFrom: coordinatedURL)
        let output = try FileHandle(forWritingTo: destinationURL)
        defer {
          input.closeFile()
          output.closeFile()
        }
        while true {
          let data = input.readData(ofLength: 64 * 1024)
          if data.isEmpty { break }
          let next = copiedBytes + UInt64(data.count)
          guard next <= Self.maximumIncomingBookBytes else {
            throw IncomingBookError.fileTooLarge
          }
          guard next <= Self.maximumIncomingRequestBytes - aggregateBefore else {
            throw IncomingBookError.aggregateTooLarge
          }
          output.write(data)
          copiedBytes = next
        }
        output.synchronizeFile()
      } catch {
        copyError = error
      }
    }
    if let coordinationError { throw coordinationError }
    if let copyError { throw copyError }
    return copiedBytes
  }

  private func completeIncomingRequest(requestId: String, deleteFiles: Bool) -> Bool {
    guard let index = incomingRequests.firstIndex(where: {
      ($0["requestId"] as? String) == requestId
    }) else {
      return false
    }
    let request = incomingRequests.remove(at: index)
    let requestDirectory = requestDirectory(for: request)
    if deleteFiles,
       let requestDirectory {
      try? FileManager.default.removeItem(at: requestDirectory)
    } else if let requestDirectory {
      try? FileManager.default.removeItem(
        at: requestDirectory.appendingPathComponent(Self.requestManifestName)
      )
    }
    return true
  }

  private func deliverIncomingRequest(_ request: [String: Any]) {
    guard let requestId = request["requestId"] as? String else { return }
    if let index = incomingRequests.firstIndex(where: {
      ($0["requestId"] as? String) == requestId
    }) {
      incomingRequests[index] = request
      return
    }
    incomingRequests.append(request)
    incomingChannel?.invokeMethod("incomingBooks", arguments: request)
  }

  private func incomingRoot() throws -> URL {
    guard let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      throw IncomingBookError.cacheUnavailable
    }
    let root = cache.appendingPathComponent("incoming_books", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func persistRequest(_ request: [String: Any], in directory: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: request)
    let manifest = directory.appendingPathComponent(Self.requestManifestName)
    try data.write(to: manifest, options: [.atomic])
  }

  private func loadPersistedRequests() -> [[String: Any]] {
    guard let root = try? incomingRoot(),
          let directories = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
          ) else {
      return []
    }
    var requests: [[String: Any]] = []
    for directory in directories {
      guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
        continue
      }
      let manifest = directory.appendingPathComponent(Self.requestManifestName)
      guard let data = try? Data(contentsOf: manifest),
            let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let requestId = request["requestId"] as? String,
            requestId == directory.lastPathComponent,
            requestDirectory(for: request)?.standardizedFileURL == directory.standardizedFileURL else {
        try? FileManager.default.removeItem(at: directory)
        continue
      }
      requests.append(request)
    }
    return requests
  }

  private func requestDirectory(for request: [String: Any]) -> URL? {
    guard let requestId = request["requestId"] as? String,
          UUID(uuidString: requestId) != nil,
          let items = request["items"] as? [[String: Any]],
          !items.isEmpty,
          let root = try? incomingRoot() else {
      return nil
    }
    let directory = root.appendingPathComponent(requestId, isDirectory: true).standardizedFileURL
    let prefix = directory.path + "/"
    for item in items {
      guard let localPath = item["localPath"] as? String,
            URL(fileURLWithPath: localPath).standardizedFileURL.path.hasPrefix(prefix),
            FileManager.default.fileExists(atPath: localPath) else {
        return nil
      }
    }
    return directory
  }

  private func uniqueDestination(in directory: URL, fileName: String) -> URL {
    let source = URL(fileURLWithPath: fileName)
    let base = source.deletingPathExtension().lastPathComponent
    let ext = source.pathExtension
    for index in 0..<1000 {
      let suffix = index == 0 ? "" : " (\(index))"
      let candidateName = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
      let candidate = directory.appendingPathComponent(candidateName)
      if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }
    return directory.appendingPathComponent(UUID().uuidString)
  }

  private func safeFileName(_ raw: String) -> String {
    let invalid = CharacterSet(charactersIn: "/\\:\0").union(.controlCharacters)
    let cleaned = raw.components(separatedBy: invalid).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
    return truncateFileNameByUTF8Bytes(
      cleaned.isEmpty ? "book" : cleaned,
      maxBytes: 180
    )
  }

  private func truncateFileNameByUTF8Bytes(_ value: String, maxBytes: Int) -> String {
    guard value.lengthOfBytes(using: .utf8) > maxBytes else { return value }
    let fileExtension = (value as NSString).pathExtension
    let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
    let stemLimit = max(1, maxBytes - suffix.lengthOfBytes(using: .utf8))
    let stem = (value as NSString).deletingPathExtension
    var result = ""
    var bytes = 0
    for character in stem {
      let next = String(character)
      let nextBytes = next.lengthOfBytes(using: .utf8)
      if bytes + nextBytes > stemLimit { break }
      result.append(character)
      bytes += nextBytes
    }
    return (result.isEmpty ? "book" : result) + suffix
  }

  private func supportedExtension(_ raw: String) -> Bool {
    let ext = raw.lowercased()
    return ["txt", "epub"].contains(ext)
  }

  private func mimeType(for rawExtension: String) -> String {
    switch rawExtension.lowercased() {
    case "txt": return "text/plain"
    case "epub": return "application/epub+zip"
    default: return "application/octet-stream"
    }
  }
}

private enum IncomingBookError: Error {
  case cacheUnavailable
  case noSupportedFiles
  case tooManyFiles
  case fileTooLarge
  case aggregateTooLarge
}
