import Foundation
import PackagePlugin

/// A plugin that generates Swift source by running an executable file with a known path in the
/// filesystem.
@main
struct ExecutablePlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectoryURL/"ExecutableOutput.swift"

    return [
      .buildCommand(
        displayName: "Running Echo1Into2",
        executable: .file(context.package.directoryURL/"DemoScripts"/(osIsWindows ? "Echo1Into2.cmd" : "Echo1Into2")),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: [ "let executableOutput = 1", outputFile.platformString ],
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

