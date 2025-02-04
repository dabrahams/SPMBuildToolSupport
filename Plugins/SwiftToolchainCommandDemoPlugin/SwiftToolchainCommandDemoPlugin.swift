import Foundation
import PackagePlugin

@main
struct LocalTargetCommandDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let rawCCode = context.package.directoryURL/"DemoScripts"/"Dummy.c"
    let preprocessedOutput = context.pluginWorkDirectoryURL/"Dummy.pp"

    return [
      .buildCommand(
        displayName: "Generating preprocessed C as resource",
        executable: .swiftToolchainCommand("clang"),
        arguments: ["-E", rawCCode.platformString, "-o",  preprocessedOutput.platformString],
        inputFiles: [rawCCode],
        outputFiles: [preprocessedOutput])
    ]
  }

}

