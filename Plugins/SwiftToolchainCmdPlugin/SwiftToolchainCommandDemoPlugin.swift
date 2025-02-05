import Foundation
import PackagePlugin

@main
struct CmdTgtPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    let rawCCode = context.package.directory/"DemoScripts"/"Dummy.c"
    let preprocessedOutput = context.pluginWorkDirectory/"Dummy.pp"

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

