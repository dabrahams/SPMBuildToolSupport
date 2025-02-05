import Foundation
print("Echoing \(String(reflecting: CommandLine.arguments[1])) into \(String(reflecting: CommandLine.arguments[2]))")
try CommandLine.arguments[1].write(
  to: URL(fileURLWithPath: CommandLine.arguments[2]), atomically: true, encoding: .utf8)
