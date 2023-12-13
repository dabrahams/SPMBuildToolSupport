import Foundation
import PackagePlugin

@main
struct LocalTargetCommandDemoPlugin: SPMBuildToolPlugin {

  func buildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [SPMBuildCommand] {

    // Treating the inputs as sources causes SPM to (incorrectly) warn that they are unhandled.
    // let inputs = (target as! SourceModuleTarget)
    //   .sourceFiles(withSuffix: ".in").map(\.path)
    let inputDirectory = target.directory.url / "SourceGenerationInputs"

    let inputs = try FileManager.default
      .subpathsOfDirectory(atPath: inputDirectory.platformString)
      .map { (inputDirectory/$0).spmPath }

    let workDirectory = context.pluginWorkDirectory
    let outputDirectory = workDirectory.appending(subpath: "GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appending(subpath: $0.lastComponent.dropLast(2) + "out")
    }

    return [
      .buildCommand(
        displayName: "Running GenerateResource",
        executable: .targetInThisPackage("GenerateResource"),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: (inputs + [ outputDirectory ]).map(\.platformString),
        inputFiles: inputs,
        outputFiles: outputs)
    ]
  }

}

