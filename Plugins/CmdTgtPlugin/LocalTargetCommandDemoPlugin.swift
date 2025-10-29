import Foundation
import PackagePlugin

@main
struct CmdTgtPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    // Treating the inputs as sources causes SPM to (incorrectly) warn that they are unhandled.
    // let inputs = (target as! SourceModuleTarget)
    //   .sourceFiles(withSuffix: ".in").map(\.path)
    let inputDirectory = target.directoryURL / "BuildToolPluginInputs"

    let inputs = try FileManager.default
      .subpathsOfDirectory(atPath: inputDirectory.platformString)
      .map { inputDirectory/$0 }

    let workDirectory = context.pluginWorkDirectoryURL
    let outputDirectory = workDirectory / "GeneratedResources"

    let outputs = inputs.map {
      outputDirectory / ($0.lastPathComponent.dropLast(2) + "out")
    }

    return [
      .buildCommand(
        displayName: "Running GenRsrc",
        executable: .targetInThisPackage("GenRsrc"),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: (inputs + [ outputDirectory ]).map(\URL.platformString),
        inputFiles: inputs,
        outputFiles: outputs)
    ]
  }

}

