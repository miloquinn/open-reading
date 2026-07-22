import Flutter
import Foundation

final class IncomingBookBridge {
  static let channelName = "com.niki.xxread/incoming_books"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    IncomingBookInbox.shared.attach(channel: channel)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialIncomingBooks":
        result(IncomingBookInbox.shared.takeInitialRequests())
      case "completeIncomingRequest":
        guard let arguments = call.arguments as? [String: Any],
              let requestID = arguments["requestId"] as? String,
              let deleteFiles = arguments["deleteFiles"] as? Bool else {
          result(
            FlutterError(
              code: "invalid_args",
              message: "requestId and deleteFiles are required",
              details: nil
            )
          )
          return
        }
        do {
          try IncomingBookInbox.shared.completeRequest(
            requestID: requestID,
            deleteFiles: deleteFiles
          )
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "incoming_cleanup_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class IncomingBookInbox {
  static let shared = IncomingBookInbox()

  private static let inboxDirectoryName = "IncomingBooks"
  private static let supportedExtensions = Set(["txt", "epub", "pdf"])
  private static let maxItemCount = 10
  private static let maxFileBytes: Int64 = 100 * 1024 * 1024
  private static let maxAggregateBytes: Int64 = 500 * 1024 * 1024
  private static let mimeTypes = [
    "txt": "text/plain",
    "epub": "application/epub+zip",
    "pdf": "application/pdf",
  ]

  private let fileManager: FileManager
  private let stateQueue = DispatchQueue(label: "com.niki.xxread.incoming-books.state")
  private let materializationQueue = DispatchQueue(
    label: "com.niki.xxread.incoming-books.materialization",
    qos: .userInitiated
  )
  private var channel: FlutterMethodChannel?
  private var pendingRequests: [[String: Any]] = []
  private var initialRequestsTaken = false
  private var sharedManifestsInFlight = Set<String>()

  private init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func attach(channel: FlutterMethodChannel) {
    stateQueue.sync {
      self.channel = channel
    }
    restorePersistedRequests()
    consumeSharedExtensionInboxIfConfigured()
  }

  func takeInitialRequests() -> [[String: Any]] {
    stateQueue.sync {
      initialRequestsTaken = true
      return pendingRequests
    }
  }

  func completeRequest(requestID: String, deleteFiles: Bool) throws {
    guard Self.isValidRequestID(requestID) else {
      throw IncomingBookError.invalidRequestID
    }
    let requestDirectory = try requestDirectoryURL(requestID: requestID, create: false)
    if deleteFiles {
      if fileManager.fileExists(atPath: requestDirectory.path) {
        try fileManager.removeItem(at: requestDirectory)
      }
    } else {
      let manifestURL = requestDirectory.appendingPathComponent(".request.json")
      if fileManager.fileExists(atPath: manifestURL.path) {
        try fileManager.removeItem(at: manifestURL)
      }
    }
    stateQueue.sync {
      pendingRequests.removeAll { ($0["requestId"] as? String) == requestID }
    }
  }

  func accept(
    urls: [URL],
    action: String = "open",
    completion: ((Bool) -> Void)? = nil
  ) {
    let uniqueURLs = Self.uniqueSupportedFileURLs(urls)
    guard !uniqueURLs.isEmpty else {
      completion?(false)
      return
    }

    let requestID = UUID().uuidString.lowercased()
    materializationQueue.async { [weak self] in
      guard let self else {
        completion?(false)
        return
      }
      var requestDirectory: URL?
      do {
        let createdRequestDirectory = try self.makeRequestDirectory(requestID: requestID)
        requestDirectory = createdRequestDirectory
        if uniqueURLs.count > Self.maxItemCount {
          let request = Self.failureRequest(
            requestID: requestID,
            action: action,
            errorCode: "too_many_files"
          )
          try self.persist(request: request, in: createdRequestDirectory)
          self.deliver(request)
          completion?(true)
          return
        }
        var items: [[String: Any]] = []
        var failures: [[String: Any]] = []
        var copiedAggregate: Int64 = 0
        for url in uniqueURLs {
          do {
            let item = try self.materialize(
              sourceURL: url,
              requestDirectory: createdRequestDirectory,
              aggregateBytesRemaining: Self.maxAggregateBytes - copiedAggregate
            )
            items.append(item)
            copiedAggregate += (item["sizeBytes"] as? NSNumber)?.int64Value ?? 0
          } catch {
            failures.append([
              "errorCode": Self.errorCode(for: error),
              "displayName": Self.sanitizedDisplayName(
                url.lastPathComponent,
                fallbackExtension: url.pathExtension.lowercased()
              ),
            ])
            NSLog(
              "Incoming book materialization failed (scheme=%@, extension=%@, error=%@)",
              url.scheme ?? "unknown",
              url.pathExtension.lowercased(),
              String(describing: type(of: error))
            )
            if case IncomingBookError.aggregateTooLarge = error {
              break
            }
          }
        }
        var request: [String: Any] = [
          "requestId": requestID,
          "action": action == "share" ? "share" : "open",
          "items": items,
          "failures": failures,
        ]
        if items.isEmpty {
          request["errorCode"] = failures.first?["errorCode"] ?? "materialize_failed"
        }
        try self.persist(request: request, in: createdRequestDirectory)
        self.deliver(request)
        completion?(true)
      } catch {
        if let requestDirectory {
          try? self.fileManager.removeItem(at: requestDirectory)
        }
        NSLog("Incoming book request setup failed (error=%@)", String(describing: type(of: error)))
        completion?(false)
      }
    }
  }

  func consumeSharedExtensionInboxIfConfigured() {
    guard let appGroupIdentifier = Bundle.main.object(
      forInfoDictionaryKey: "OpenReadingAppGroupIdentifier"
    ) as? String,
      !appGroupIdentifier.isEmpty,
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      ) else {
      return
    }

    let manifestsDirectory = containerURL
      .appendingPathComponent("IncomingBooks", isDirectory: true)
      .appendingPathComponent("manifests", isDirectory: true)
    materializationQueue.async { [weak self] in
      guard let self,
            let manifestURLs = try? self.fileManager.contentsOfDirectory(
              at: manifestsDirectory,
              includingPropertiesForKeys: nil,
              options: [.skipsHiddenFiles]
            ) else {
        return
      }
      for manifestURL in manifestURLs where manifestURL.pathExtension == "json" {
        guard self.claimSharedManifest(manifestURL) else { continue }
        let payloadsRoot = containerURL
          .appendingPathComponent("IncomingBooks", isDirectory: true)
          .appendingPathComponent("payloads", isDirectory: true)
          .standardizedFileURL
        let filenameRequestID = manifestURL.deletingPathExtension().lastPathComponent
        guard Self.isValidRequestID(filenameRequestID) else {
          self.discardPermanentlyInvalidSharedManifest(
            manifestURL,
            payloadsRoot: payloadsRoot,
            boundRequestID: nil
          )
          self.releaseSharedManifest(manifestURL)
          continue
        }

        let data: Data
        do {
          data = try Data(contentsOf: manifestURL)
        } catch {
          self.releaseSharedManifest(manifestURL)
          NSLog("Shared incoming-book manifest read deferred (error=%@)", String(describing: type(of: error)))
          continue
        }

        guard let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sharedRequestID = manifest["requestId"] as? String,
              Self.isValidRequestID(sharedRequestID),
              sharedRequestID == filenameRequestID,
              let paths = manifest["paths"] as? [String],
              !paths.isEmpty,
              paths.count <= Self.maxItemCount else {
          self.discardPermanentlyInvalidSharedManifest(
            manifestURL,
            payloadsRoot: payloadsRoot,
            boundRequestID: filenameRequestID
          )
          self.releaseSharedManifest(manifestURL)
          continue
        }

        let urls: [URL]
        do {
          urls = try paths.map {
            try Self.validatedSharedPayloadURL(
              relativePath: $0,
              root: payloadsRoot,
              expectedRequestID: sharedRequestID
            )
          }
        } catch {
          self.discardPermanentlyInvalidSharedManifest(
            manifestURL,
            payloadsRoot: payloadsRoot,
            boundRequestID: sharedRequestID
          )
          self.releaseSharedManifest(manifestURL)
          continue
        }

        self.accept(
          urls: urls,
          action: "share"
        ) { success in
          if success {
            let sharedRequestDirectory = payloadsRoot.appendingPathComponent(
              sharedRequestID,
              isDirectory: true
            )
            do {
              if self.fileManager.fileExists(atPath: sharedRequestDirectory.path) {
                try self.fileManager.removeItem(at: sharedRequestDirectory)
              }
              try self.fileManager.removeItem(at: manifestURL)
            } catch {
              NSLog("Shared incoming-book cleanup deferred (error=%@)", String(describing: type(of: error)))
            }
          }
          self.releaseSharedManifest(manifestURL)
        }
      }
    }
  }

  static func uniqueSupportedFileURLs(_ urls: [URL]) -> [URL] {
    var seen = Set<String>()
    return urls.filter { url in
      guard url.isFileURL,
            supportedExtensions.contains(url.pathExtension.lowercased()) else {
        return false
      }
      return seen.insert(url.standardizedFileURL.absoluteString).inserted
    }
  }

  static func sanitizedDisplayName(_ value: String, fallbackExtension: String) -> String {
    let lastComponent = (value as NSString).lastPathComponent
    let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
    let filteredScalars = lastComponent.unicodeScalars.map { scalar -> Character in
      forbidden.contains(scalar) ? "_" : Character(String(scalar))
    }
    var name = String(filteredScalars).trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty || name == "." || name == ".." {
      name = "book.\(fallbackExtension)"
    }
    return truncateFileNameByUTF8Bytes(name, maxBytes: 180)
  }

  static func truncateFileNameByUTF8Bytes(_ value: String, maxBytes: Int) -> String {
    guard value.lengthOfBytes(using: .utf8) > maxBytes else { return value }
    let extensionPart = (value as NSString).pathExtension
    let suffix = extensionPart.isEmpty ? "" : ".\(extensionPart)"
    let suffixBytes = suffix.lengthOfBytes(using: .utf8)
    let stemLimit = max(1, maxBytes - suffixBytes)
    let stem = (value as NSString).deletingPathExtension
    var truncated = ""
    var byteCount = 0
    for character in stem {
      let characterString = String(character)
      let characterBytes = characterString.lengthOfBytes(using: .utf8)
      if byteCount + characterBytes > stemLimit { break }
      truncated.append(character)
      byteCount += characterBytes
    }
    if truncated.isEmpty { truncated = "book" }
    let candidate = truncated + suffix
    return candidate.lengthOfBytes(using: .utf8) <= maxBytes
      ? candidate
      : String(truncated.prefix(1))
  }

  static func validatedSharedPayloadURL(
    relativePath: String,
    root: URL,
    expectedRequestID: String
  ) throws -> URL {
    let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !relativePath.isEmpty,
          !relativePath.hasPrefix("/"),
          isValidRequestID(expectedRequestID),
          components.count == 2,
          String(components[0]) == expectedRequestID,
          !components[1].isEmpty,
          !components.contains(".."),
          !components.contains(".") else {
      throw IncomingBookError.invalidSharedManifest
    }
    let candidate = root
      .appendingPathComponent(relativePath)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let rootPrefix = root.standardizedFileURL.resolvingSymlinksInPath().path + "/"
    var isDirectory: ObjCBool = false
    guard candidate.path.hasPrefix(rootPrefix),
          FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
      throw IncomingBookError.invalidSharedManifest
    }
    return candidate
  }

  static func isValidRequestID(_ requestID: String) -> Bool {
    guard !requestID.isEmpty, requestID.count <= 64 else { return false }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
    return requestID.unicodeScalars.allSatisfy(allowed.contains)
  }

  static func errorCode(for error: Error) -> String {
    if let incomingError = error as? IncomingBookError {
      switch incomingError {
      case .notARegularFile:
        return "no_book_file"
      case .fileTooLarge:
        return "file_too_large"
      case .aggregateTooLarge:
        return "aggregate_too_large"
      case .formatContentMismatch:
        return "format_content_mismatch"
      case .unsupportedType:
        return "unsupported_format"
      default:
        return "materialize_failed"
      }
    }
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain,
       [NSFileReadNoPermissionError, NSFileReadNoSuchFileError].contains(nsError.code) {
      return "file_access_lost"
    }
    return "materialize_failed"
  }

  private func makeRequestDirectory(requestID: String) throws -> URL {
    let requestDirectory = try requestDirectoryURL(requestID: requestID, create: true)
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var mutableRoot = requestDirectory.deletingLastPathComponent()
    try? mutableRoot.setResourceValues(resourceValues)
    return requestDirectory
  }

  private func requestDirectoryURL(requestID: String, create: Bool) throws -> URL {
    guard Self.isValidRequestID(requestID) else {
      throw IncomingBookError.invalidRequestID
    }
    let applicationSupport = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let inboxRoot = applicationSupport.appendingPathComponent(
      Self.inboxDirectoryName,
      isDirectory: true
    )
    let requestDirectory = inboxRoot.appendingPathComponent(requestID, isDirectory: true)
    if create {
      try fileManager.createDirectory(
        at: requestDirectory,
        withIntermediateDirectories: true
      )
    }
    return requestDirectory
  }

  private func persist(request: [String: Any], in requestDirectory: URL) throws {
    let manifestURL = requestDirectory.appendingPathComponent(".request.json")
    let data = try JSONSerialization.data(withJSONObject: request)
    try data.write(to: manifestURL, options: [.atomic])
  }

  private func restorePersistedRequests() {
    materializationQueue.async { [weak self] in
      guard let self,
            let inboxRoot = try? self.inboxRootURL(create: true),
            let directories = try? self.fileManager.contentsOfDirectory(
              at: inboxRoot,
              includingPropertiesForKeys: [.isDirectoryKey],
              options: [.skipsHiddenFiles]
            ) else {
        return
      }
      for directory in directories {
        let requestID = directory.lastPathComponent
        guard Self.isValidRequestID(requestID) else { continue }
        let manifestURL = directory.appendingPathComponent(".request.json")
        do {
          let data = try Data(contentsOf: manifestURL)
          guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                Self.isValidPersistedRequest(
                  request,
                  requestID: requestID,
                  requestDirectory: directory,
                  fileManager: self.fileManager
                ) else {
            throw IncomingBookError.invalidPersistedRequest
          }
          self.deliver(request)
        } catch {
          try? self.fileManager.removeItem(at: directory)
          NSLog(
            "Persisted incoming-book request rejected (requestId=%@, error=%@)",
            requestID,
            String(describing: type(of: error))
          )
        }
      }
    }
  }

  private func inboxRootURL(create: Bool) throws -> URL {
    let applicationSupport = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let inboxRoot = applicationSupport.appendingPathComponent(
      Self.inboxDirectoryName,
      isDirectory: true
    )
    if create {
      try fileManager.createDirectory(at: inboxRoot, withIntermediateDirectories: true)
    }
    return inboxRoot
  }

  private static func isValidPersistedRequest(
    _ request: [String: Any],
    requestID: String,
    requestDirectory: URL,
    fileManager: FileManager
  ) -> Bool {
    guard request["requestId"] as? String == requestID,
          let action = request["action"] as? String,
          action == "open" || action == "share",
          let items = request["items"] as? [[String: Any]] else {
      return false
    }
    if items.isEmpty {
      return request["errorCode"] is String
    }
    let directoryPrefix = requestDirectory.standardizedFileURL.path + "/"
    return items.allSatisfy { item in
      guard let localPath = item["localPath"] as? String,
            let displayName = item["displayName"] as? String,
            let mimeType = item["mimeType"] as? String,
            !displayName.isEmpty,
            !mimeType.isEmpty else {
        return false
      }
      let fileURL = URL(fileURLWithPath: localPath).standardizedFileURL
      return fileURL.path.hasPrefix(directoryPrefix)
        && fileManager.fileExists(atPath: fileURL.path)
        && supportedExtensions.contains(fileURL.pathExtension.lowercased())
    }
  }

  private func materialize(
    sourceURL: URL,
    requestDirectory: URL,
    aggregateBytesRemaining: Int64
  ) throws -> [String: Any] {
    let fileExtension = sourceURL.pathExtension.lowercased()
    guard Self.supportedExtensions.contains(fileExtension) else {
      throw IncomingBookError.unsupportedType
    }
    let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if accessedSecurityScope {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    let sourceValues = try sourceURL.resourceValues(forKeys: [
      .isRegularFileKey,
      .fileSizeKey,
      .contentModificationDateKey,
    ])
    guard sourceValues.isRegularFile != false else {
      throw IncomingBookError.notARegularFile
    }
    if let declaredSize = sourceValues.fileSize.map(Int64.init),
       declaredSize > Self.maxFileBytes {
      throw IncomingBookError.fileTooLarge
    }
    if let declaredSize = sourceValues.fileSize.map(Int64.init),
       declaredSize > aggregateBytesRemaining {
      throw IncomingBookError.aggregateTooLarge
    }
    let displayName = Self.sanitizedDisplayName(
      sourceURL.lastPathComponent,
      fallbackExtension: fileExtension
    )
    let destinationURL = uniqueDestinationURL(
      directory: requestDirectory,
      displayName: displayName
    )
    let partialURL = requestDirectory.appendingPathComponent(
      ".partial-\(UUID().uuidString.lowercased())"
    )
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var copyError: Error?
    var copiedBytes: Int64 = 0
    coordinator.coordinate(
      readingItemAt: sourceURL,
      options: [.withoutChanges],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        copiedBytes = try Self.streamCopy(
          from: coordinatedURL,
          to: partialURL,
          aggregateBytesRemaining: aggregateBytesRemaining
        )
        try fileManager.moveItem(at: partialURL, to: destinationURL)
      } catch {
        copyError = error
      }
    }
    if let coordinationError {
      try? fileManager.removeItem(at: partialURL)
      try? fileManager.removeItem(at: destinationURL)
      throw coordinationError
    }
    if let copyError {
      try? fileManager.removeItem(at: partialURL)
      try? fileManager.removeItem(at: destinationURL)
      throw copyError
    }
    do {
      try Self.validateBasicSignature(destinationURL, extension: fileExtension)
    } catch {
      try? fileManager.removeItem(at: destinationURL)
      throw error
    }

    let destinationValues = try destinationURL.resourceValues(forKeys: [
      .fileSizeKey,
      .contentModificationDateKey,
    ])
    var item: [String: Any] = [
      "id": UUID().uuidString.lowercased(),
      "displayName": destinationURL.lastPathComponent,
      "localPath": destinationURL.path,
      "mimeType": Self.mimeTypes[fileExtension] ?? "application/octet-stream",
    ]
    item["sizeBytes"] = destinationValues.fileSize
      ?? sourceValues.fileSize
      ?? Int(copiedBytes)
    if let modifiedTime = destinationValues.contentModificationDate
      ?? sourceValues.contentModificationDate {
      item["modifiedTime"] = Int(modifiedTime.timeIntervalSince1970 * 1000)
    }
    return item
  }

  private func uniqueDestinationURL(directory: URL, displayName: String) -> URL {
    let first = directory.appendingPathComponent(displayName, isDirectory: false)
    guard fileManager.fileExists(atPath: first.path) else { return first }
    let fileExtension = (displayName as NSString).pathExtension
    let stem = (displayName as NSString).deletingPathExtension
    for index in 1...9999 {
      let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
      let candidate = directory.appendingPathComponent(
        "\(stem) (\(index))\(suffix)",
        isDirectory: false
      )
      if !fileManager.fileExists(atPath: candidate.path) {
        return candidate
      }
    }
    return directory.appendingPathComponent(
      "\(UUID().uuidString.lowercased()).\(fileExtension)",
      isDirectory: false
    )
  }

  private static func streamCopy(
    from sourceURL: URL,
    to destinationURL: URL,
    aggregateBytesRemaining: Int64
  ) throws -> Int64 {
    guard let input = InputStream(url: sourceURL),
          let output = OutputStream(url: destinationURL, append: false) else {
      throw IncomingBookError.streamUnavailable
    }
    input.open()
    output.open()
    defer {
      input.close()
      output.close()
    }

    let bufferSize = 64 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    var copiedBytes: Int64 = 0
    while true {
      let bytesRead = input.read(buffer, maxLength: bufferSize)
      if bytesRead < 0 {
        throw input.streamError ?? IncomingBookError.readFailed
      }
      if bytesRead == 0 { break }
      let nextTotal = copiedBytes + Int64(bytesRead)
      if nextTotal > maxFileBytes {
        throw IncomingBookError.fileTooLarge
      }
      if nextTotal > aggregateBytesRemaining {
        throw IncomingBookError.aggregateTooLarge
      }
      var offset = 0
      while offset < bytesRead {
        let bytesWritten = output.write(
          buffer.advanced(by: offset),
          maxLength: bytesRead - offset
        )
        if bytesWritten <= 0 {
          throw output.streamError ?? IncomingBookError.writeFailed
        }
        offset += bytesWritten
      }
      copiedBytes = nextTotal
    }
    return copiedBytes
  }

  private static func validateBasicSignature(_ url: URL, extension fileExtension: String) throws {
    guard fileExtension == "pdf" || fileExtension == "epub" else { return }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let header = try handle.read(upToCount: 8) ?? Data()
    let valid: Bool
    if fileExtension == "pdf" {
      valid = header.starts(with: Data("%PDF-".utf8))
    } else {
      valid = header.starts(with: Data([0x50, 0x4b, 0x03, 0x04]))
        || header.starts(with: Data([0x50, 0x4b, 0x05, 0x06]))
        || header.starts(with: Data([0x50, 0x4b, 0x07, 0x08]))
    }
    if !valid { throw IncomingBookError.formatContentMismatch }
  }

  private static func failureRequest(
    requestID: String,
    action: String,
    errorCode: String
  ) -> [String: Any] {
    [
      "requestId": requestID,
      "action": action == "share" ? "share" : "open",
      "items": [],
      "failures": [["errorCode": errorCode]],
      "errorCode": errorCode,
    ]
  }

  private func deliver(_ request: [String: Any]) {
    var eventChannel: FlutterMethodChannel?
    stateQueue.sync {
      let requestID = request["requestId"] as? String
      let isNewRequest = !pendingRequests.contains {
        ($0["requestId"] as? String) == requestID
      }
      if isNewRequest {
        pendingRequests.append(request)
      }
      if isNewRequest, initialRequestsTaken, let channel {
        eventChannel = channel
      }
    }
    guard let eventChannel else { return }
    DispatchQueue.main.async {
      eventChannel.invokeMethod("incomingBooks", arguments: request)
    }
  }

  private func claimSharedManifest(_ url: URL) -> Bool {
    stateQueue.sync {
      sharedManifestsInFlight.insert(url.standardizedFileURL.path).inserted
    }
  }

  private func discardPermanentlyInvalidSharedManifest(
    _ manifestURL: URL,
    payloadsRoot: URL,
    boundRequestID: String?
  ) {
    do {
      if let boundRequestID, Self.isValidRequestID(boundRequestID) {
        let requestDirectory = payloadsRoot.appendingPathComponent(
          boundRequestID,
          isDirectory: true
        )
        if fileManager.fileExists(atPath: requestDirectory.path) {
          try fileManager.removeItem(at: requestDirectory)
        }
      }
      if fileManager.fileExists(atPath: manifestURL.path) {
        try fileManager.removeItem(at: manifestURL)
      }
    } catch {
      NSLog("Invalid shared incoming-book cleanup deferred (error=%@)", String(describing: type(of: error)))
    }
  }

  private func releaseSharedManifest(_ url: URL) {
    _ = stateQueue.sync {
      sharedManifestsInFlight.remove(url.standardizedFileURL.path)
    }
  }
}

private enum IncomingBookError: Error {
  case aggregateTooLarge
  case fileTooLarge
  case formatContentMismatch
  case invalidPersistedRequest
  case invalidRequestID
  case invalidSharedManifest
  case notARegularFile
  case readFailed
  case streamUnavailable
  case unsupportedType
  case writeFailed
}
