import Foundation
import PackagePlugin

/// A plugin that generates Swift source by running an executable file with a known path in the
/// filesystem.
@main
struct SwiftScriptPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let outputFile = context.pluginWorkDirectoryURL/"SwiftScriptOutput.swift"

    return [
      .buildCommand(
        displayName: "Running Echo1Into2.swift",
        executable: .swiftScript(context.package.directoryURL/"DemoScripts"/"Echo1Into2.swift"),
        arguments: [ "let swiftScriptOutput = 1", outputFile.platformString ],
        inputFiles: [],
        outputFiles: [outputFile])
    ]
  }

}

