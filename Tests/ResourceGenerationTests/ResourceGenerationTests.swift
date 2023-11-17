import XCTest
import LibWithResource
import Foundation

final class ResourceGenerationTests: XCTestCase {

  func testIt() throws {
    guard let test1 = resourceBundle.url(forResource: "Test1.out", withExtension: nil) else {
      XCTFail("Test1.out not found.")
      return
    }
    let content1 = try String(contentsOf: test1, encoding: .utf8)
    XCTAssert(content1.hasSuffix("\n# PROCESSED!\n"))

    guard let test2 = resourceBundle.url(forResource: "Test2.out", withExtension: nil) else {
      XCTFail("Test2.out not found.")
      return
    }
    let content2 = try String(contentsOf: test2, encoding: .utf8)
    XCTAssert(content2.hasSuffix("\n# PROCESSED!\n"))
  }
}
