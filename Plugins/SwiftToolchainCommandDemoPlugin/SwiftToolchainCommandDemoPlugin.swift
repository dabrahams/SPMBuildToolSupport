import Foundation
import PackagePlugin

@main
struct LocalTargetCommandDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let swiftToDump = context.package.directory/"DemoScripts"/"Echo1Into2.swift"
    let astFile = context.pluginWorkDirectory/"AST.txt"

    return [
      .buildCommand(
        displayName: "Generating AST dump as resource",
        executable: .swiftToolchainCommand("swiftc"),
        arguments: ["-dump-ast", swiftToDump.platformString, "-o",  astFile.platformString],
        inputFiles: [swiftToDump],
        outputFiles: [astFile])
    ]
  }

}

