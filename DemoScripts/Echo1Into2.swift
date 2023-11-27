import Foundation
try CommandLine.arguments[1].write(
  to: URL(fileURLWithPath: CommandLine.arguments[2]), atomically: true, encoding: .utf8)
