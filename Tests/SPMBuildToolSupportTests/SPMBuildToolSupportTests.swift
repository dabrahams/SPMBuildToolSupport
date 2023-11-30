import XCTest
import LibWithResourceGeneratedByLocalTarget
import LibWithResourceGeneratedBySwiftToolchainCommand
import Foundation

final class SPMBuildToolSupportTests: XCTestCase {

  func testLocalTargetCommand() throws {
    guard let test1 = resourcesGeneratedByLocalTarget.url(forResource: "Test1.out", withExtension: nil) else {
      XCTFail("Test1.out not found.")
      return
    }
    let content1 = try String(contentsOf: test1, encoding: .utf8)
    XCTAssert(content1.hasSuffix("\n# PROCESSED!\n"))

    guard let test2 = resourcesGeneratedByLocalTarget.url(forResource: "Test2.out", withExtension: nil) else {
      XCTFail("Test2.out not found.")
      return
    }
    let content2 = try String(contentsOf: test2, encoding: .utf8)
    XCTAssert(content2.hasSuffix("\n# PROCESSED!\n"))
  }

  func testSwiftToolchainCommand() throws {
    if resourcesGeneratedBySwiftToolchainCommand.url(forResource: "AST.txt", withExtension: nil) == nil {
      XCTFail("AST.text not found.")
    }
  }

}
