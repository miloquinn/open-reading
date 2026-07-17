import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testICloudLocatorStaysInsideBooksDirectory() throws {
    let root = URL(fileURLWithPath: "/tmp/OpenReading/Documents/books", isDirectory: true)
    let resolved = try StorageBridge.validatedSourceURL(
      locator: "novels/example.epub",
      root: root
    )

    XCTAssertEqual(
      resolved.path,
      "/tmp/OpenReading/Documents/books/novels/example.epub"
    )
  }

  func testICloudLocatorRejectsParentTraversal() {
    let root = URL(fileURLWithPath: "/tmp/OpenReading/Documents/books", isDirectory: true)

    XCTAssertThrowsError(
      try StorageBridge.validatedSourceURL(
        locator: "../private/book.epub",
        root: root
      )
    )
    XCTAssertThrowsError(
      try StorageBridge.validatedSourceURL(
        locator: "/private/book.epub",
        root: root
      )
    )
  }
}
