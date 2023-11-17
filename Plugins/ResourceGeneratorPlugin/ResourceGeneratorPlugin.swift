import Foundation
import PackagePlugin

@main
struct ResourceGeneratorPlugin: PortableBuildToolPlugin {

  func portableBuildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [PortableBuildCommand] {

    let inputs = (target as! SourceModuleTarget)
      .sourceFiles(withSuffix: ".in").map(\.path)

    if inputs.isEmpty { return [] }

    let workDirectory = context.pluginWorkDirectory
    let outputDirectory = workDirectory.appending(subpath: "GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appending(subpath: $0.lastComponent.dropLast(2) + "out")
    }

    return [
      .buildCommand(
        displayName: "Running converter",
        executable: .targetInThisPackage(name: "GenerateResource"),
        // Note the use of `.platformString` on these paths rather
        // than `.string`.  Your executable tool may have trouble
        // finding files and directories with `.string`.
        arguments: (inputs + [ outputDirectory ]).map(\.platformString),
        inputFiles: inputs,
        outputFiles: outputs)
    ]
  }

}

