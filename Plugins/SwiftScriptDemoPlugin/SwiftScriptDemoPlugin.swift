import Foundation
import PackagePlugin

/// A plugin that generates Swift source by running an executable file with a known path in the
/// filesystem.
@main
struct ExecutableFileDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectory/"SwiftScriptOutput.swift"

    return [
      .buildCommand(
        displayName: "Running Echo1Into2.swift",
        executable: .swiftScript(context.package.directory/"Scripts"/"Echo1Into2.swift"),
        arguments: [ "let swiftScriptOutput = 1", outputFile.platformString ],
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

