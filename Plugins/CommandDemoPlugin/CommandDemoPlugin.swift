import Foundation
import PackagePlugin

extension Path {

  /// A representation of self suitable for use as the target of an output redirection in the
  /// platform's shell.
  var shellQuoted: String {
    if osIsWindows { return "\"\(repaired.platformString)\"" }
    let inner = repaired.platformString
      .replacingOccurrences(of: #"\"#, with: #"\\"#)
      .replacingOccurrences(of: "'", with: #"\'"#)
    return "'\(inner)'"
  }

}
/// A plugin that generates Swift source by running a command by name as if in a shell.
@main
struct CommandDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectory/"CommandOutput.swift"

    return [
      .buildCommand(
        displayName: "Running Command",
        executable: .command(osIsWindows ? "cmd" : "sh"),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: [
          osIsWindows ? "/c" : "-c",
          "echo let commandOutput = 1 > \(outputFile.shellQuoted)"
        ],
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

