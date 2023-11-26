import Foundation
import PackagePlugin

@main
struct ExistingExecutableDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectory/"Echoed.swift"

    return [
      .buildCommand(
        displayName: "Running Echo1Into2",
        executable: .existingFile(context.package.directory/"Scripts"/(osIsWindows ? "Echo1Into2.cmd" : "Echo1Into2")),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: [ "let echoed = 1", outputFile.platformString ],
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

