import Foundation
import PackagePlugin

/// A plugin that generates Swift source by running a command by name as if in a shell.
@main
struct CmdPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectoryURL/"CommandOutput.swift"

    let shell = osIsWindows ? "cmd" : "sh"
    let arguments = (osIsWindows ? [ "/Q", "/C"] : ["-c"])
    + [ "echo let commandOutput = 1 >\(outputFile.platformString)" ]

    return [
      .buildCommand(
        displayName: "Running \([shell] + arguments)",
        executable: .command(shell),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: arguments,
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

