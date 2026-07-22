import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private static let acceptedTypeIdentifiers = [
    UTType.plainText.identifier,
    "org.idpf.epub-container",
  ]

  override func isContentValid() -> Bool {
    true
  }

  override func didSelectPost() {
    guard let appGroupIdentifier = Bundle.main.object(
      forInfoDictionaryKey: "OpenReadingAppGroupIdentifier"
    ) as? String,
      !appGroupIdentifier.isEmpty,
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      ) else {
      extensionContext?.cancelRequest(withError: ShareInboxError.appGroupUnavailable)
      return
    }

    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    let acceptedProviders = providers.compactMap { provider -> (NSItemProvider, String)? in
      guard let typeIdentifier = Self.acceptedTypeIdentifiers.first(
        where: provider.hasItemConformingToTypeIdentifier
      ) else {
        return nil
      }
      return (provider, typeIdentifier)
    }
    guard !acceptedProviders.isEmpty,
          acceptedProviders.count == providers.count,
          acceptedProviders.count <= ShareCopyBudget.maxItemCount else {
      extensionContext?.cancelRequest(withError: ShareInboxError.noSupportedFiles)
      return
    }

    let requestID = UUID().uuidString.lowercased()
    let incomingRoot = containerURL.appendingPathComponent("IncomingBooks", isDirectory: true)
    let payloadDirectory = incomingRoot
      .appendingPathComponent("payloads", isDirectory: true)
      .appendingPathComponent(requestID, isDirectory: true)
    let manifestsDirectory = incomingRoot.appendingPathComponent("manifests", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: payloadDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.createDirectory(
        at: manifestsDirectory,
        withIntermediateDirectories: true
      )
      Self.pruneStaleOrphanedPayloads(
        payloadsDirectory: payloadDirectory.deletingLastPathComponent(),
        manifestsDirectory: manifestsDirectory,
        preservingRequestID: requestID
      )
    } catch {
      extensionContext?.cancelRequest(withError: error)
      return
    }

    let group = DispatchGroup()
    let resultQueue = DispatchQueue(label: "com.niki.xxread.share-extension.results")
    let copyBudget = ShareCopyBudget()
    var relativePaths: [Int: String] = [:]
    var reservedDisplayNames = Set<String>()
    var firstError: Error?
    for (index, providerAndType) in acceptedProviders.enumerated() {
      let (provider, typeIdentifier) = providerAndType
      group.enter()
      provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) {
        sourceURL,
        _,
        error in
        defer { group.leave() }
        guard let sourceURL else {
          resultQueue.sync { firstError = firstError ?? error ?? ShareInboxError.fileUnavailable }
          return
        }
        do {
          let sanitizedName = Self.sanitizedDisplayName(
            sourceURL.lastPathComponent,
            typeIdentifier: typeIdentifier
          )
          let destinationURL = resultQueue.sync {
            Self.uniqueDestinationURL(
              directory: payloadDirectory,
              displayName: sanitizedName,
              reservedDisplayNames: &reservedDisplayNames
            )
          }
          try Self.coordinatedCopy(
            from: sourceURL,
            to: destinationURL,
            budget: copyBudget
          )
          let relativePath = "\(requestID)/\(destinationURL.lastPathComponent)"
          resultQueue.sync { relativePaths[index] = relativePath }
        } catch {
          resultQueue.sync { firstError = firstError ?? error }
        }
      }
    }

    group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
      if let error = resultQueue.sync(execute: { firstError }) {
        try? FileManager.default.removeItem(at: payloadDirectory)
        DispatchQueue.main.async {
          self?.extensionContext?.cancelRequest(withError: error)
        }
        return
      }
      do {
        let paths = resultQueue.sync {
          relativePaths.sorted { $0.key < $1.key }.map(\.value)
        }
        guard !paths.isEmpty else { throw ShareInboxError.noSupportedFiles }
        let manifestData = try JSONSerialization.data(
          withJSONObject: ["requestId": requestID, "paths": paths]
        )
        let partialURL = manifestsDirectory.appendingPathComponent(".\(requestID).partial")
        let manifestURL = manifestsDirectory.appendingPathComponent("\(requestID).json")
        try manifestData.write(to: partialURL, options: [.atomic])
        try FileManager.default.moveItem(at: partialURL, to: manifestURL)
        DispatchQueue.main.async {
          self?.extensionContext?.completeRequest(returningItems: nil)
        }
      } catch {
        try? FileManager.default.removeItem(at: payloadDirectory)
        DispatchQueue.main.async {
          self?.extensionContext?.cancelRequest(withError: error)
        }
      }
    }
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private static func sanitizedDisplayName(_ value: String, typeIdentifier: String) -> String {
    let lastComponent = (value as NSString).lastPathComponent
    let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
    let filtered = lastComponent.unicodeScalars.map {
      forbidden.contains($0) ? "_" : String($0)
    }.joined()
    var name = filtered.isEmpty ? "book" : filtered
    let expectedExtension = switch typeIdentifier {
    case UTType.plainText.identifier: "txt"
    default: "epub"
    }
    if (name as NSString).pathExtension.lowercased() != expectedExtension {
      name += ".\(expectedExtension)"
    }
    return Self.truncateFileNameByUTF8Bytes(
      name,
      maxBytes: 180
    )
  }

  private static func truncateFileNameByUTF8Bytes(_ value: String, maxBytes: Int) -> String {
    guard value.lengthOfBytes(using: .utf8) > maxBytes else { return value }
    let extensionPart = (value as NSString).pathExtension
    let suffix = extensionPart.isEmpty ? "" : ".\(extensionPart)"
    let suffixBytes = suffix.lengthOfBytes(using: .utf8)
    let stemLimit = max(1, maxBytes - suffixBytes)
    let stem = (value as NSString).deletingPathExtension
    var truncated = ""
    var byteCount = 0
    for character in stem {
      let string = String(character)
      let bytes = string.lengthOfBytes(using: .utf8)
      if byteCount + bytes > stemLimit { break }
      truncated.append(character)
      byteCount += bytes
    }
    if truncated.isEmpty { truncated = "book" }
    return truncated + suffix
  }

  private static func uniqueDestinationURL(
    directory: URL,
    displayName: String,
    reservedDisplayNames: inout Set<String>
  ) -> URL {
    let manager = FileManager.default
    let first = directory.appendingPathComponent(displayName)
    if !manager.fileExists(atPath: first.path),
       reservedDisplayNames.insert(displayName).inserted {
      return first
    }
    let fileExtension = (displayName as NSString).pathExtension
    let stem = (displayName as NSString).deletingPathExtension
    for index in 1...9999 {
      let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
      let candidateName = "\(stem) (\(index))\(suffix)"
      let candidate = directory.appendingPathComponent(candidateName)
      if !manager.fileExists(atPath: candidate.path),
         reservedDisplayNames.insert(candidateName).inserted {
        return candidate
      }
    }
    let fallbackName = UUID().uuidString.lowercased() + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
    reservedDisplayNames.insert(fallbackName)
    return directory.appendingPathComponent(fallbackName)
  }

  private static func pruneStaleOrphanedPayloads(
    payloadsDirectory: URL,
    manifestsDirectory: URL,
    preservingRequestID: String
  ) {
    let manager = FileManager.default
    let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
    guard let directories = try? manager.contentsOfDirectory(
      at: payloadsDirectory,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }
    for directory in directories where directory.lastPathComponent != preservingRequestID {
      guard let values = try? directory.resourceValues(
        forKeys: [.isDirectoryKey, .contentModificationDateKey]
      ),
        values.isDirectory == true,
        let modified = values.contentModificationDate,
        modified < cutoff else {
        continue
      }
      let manifestURL = manifestsDirectory.appendingPathComponent(
        "\(directory.lastPathComponent).json"
      )
      if !manager.fileExists(atPath: manifestURL.path) {
        try? manager.removeItem(at: directory)
      }
    }
  }

  private static func coordinatedCopy(
    from sourceURL: URL,
    to destinationURL: URL,
    budget: ShareCopyBudget
  ) throws {
    let accessed = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if accessed { sourceURL.stopAccessingSecurityScopedResource() }
    }
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var copyError: Error?
    coordinator.coordinate(
      readingItemAt: sourceURL,
      options: [.withoutChanges],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        if let declaredSize = try coordinatedURL.resourceValues(
          forKeys: [.fileSizeKey]
        ).fileSize.map(Int64.init),
          declaredSize > ShareCopyBudget.maxFileBytes {
          throw ShareInboxError.fileTooLarge
        }
        try streamCopy(from: coordinatedURL, to: destinationURL, budget: budget)
      } catch {
        try? FileManager.default.removeItem(at: destinationURL)
        copyError = error
      }
    }
    if let coordinationError { throw coordinationError }
    if let copyError { throw copyError }
  }

  private static func streamCopy(
    from sourceURL: URL,
    to destinationURL: URL,
    budget: ShareCopyBudget
  ) throws {
    guard let input = InputStream(url: sourceURL),
          let output = OutputStream(url: destinationURL, append: false) else {
      throw ShareInboxError.fileUnavailable
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
    var fileBytes: Int64 = 0
    do {
      while true {
        let bytesRead = input.read(buffer, maxLength: bufferSize)
        if bytesRead < 0 {
          throw input.streamError ?? ShareInboxError.fileUnavailable
        }
        if bytesRead == 0 { break }
        try budget.reserve(bytes: Int64(bytesRead), currentFileBytes: fileBytes)
        fileBytes += Int64(bytesRead)
        var offset = 0
        while offset < bytesRead {
          let bytesWritten = output.write(
            buffer.advanced(by: offset),
            maxLength: bytesRead - offset
          )
          if bytesWritten <= 0 {
            throw output.streamError ?? ShareInboxError.fileUnavailable
          }
          offset += bytesWritten
        }
      }
    } catch {
      budget.release(bytes: fileBytes)
      throw error
    }
  }
}

private final class ShareCopyBudget {
  static let maxItemCount = 10
  static let maxFileBytes: Int64 = 100 * 1024 * 1024
  static let maxAggregateBytes: Int64 = 500 * 1024 * 1024

  private let lock = NSLock()
  private var aggregateBytes: Int64 = 0

  func reserve(bytes: Int64, currentFileBytes: Int64) throws {
    if currentFileBytes + bytes > Self.maxFileBytes {
      throw ShareInboxError.fileTooLarge
    }
    lock.lock()
    defer { lock.unlock() }
    if aggregateBytes + bytes > Self.maxAggregateBytes {
      throw ShareInboxError.aggregateTooLarge
    }
    aggregateBytes += bytes
  }

  func release(bytes: Int64) {
    lock.lock()
    aggregateBytes = max(0, aggregateBytes - bytes)
    lock.unlock()
  }
}

private enum ShareInboxError: LocalizedError {
  case appGroupUnavailable
  case aggregateTooLarge
  case fileUnavailable
  case fileTooLarge
  case noSupportedFiles

  var errorDescription: String? {
    switch self {
    case .appGroupUnavailable:
      return "The Open Reading App Group is not configured for this build"
    case .aggregateTooLarge:
      return "The selected files exceed the 500 MiB share limit"
    case .fileUnavailable:
      return "The shared file is unavailable"
    case .fileTooLarge:
      return "A shared file exceeds the 100 MiB limit"
    case .noSupportedFiles:
      return "The share does not contain a supported TXT or EPUB file"
    }
  }
}
