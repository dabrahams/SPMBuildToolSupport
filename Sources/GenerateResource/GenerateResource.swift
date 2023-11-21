import Foundation

@main
struct GenerateResource {

  static func main() throws {
    // Log our invocation for diagnostic purposes
    print("GenerateResource invocation:",  CommandLine.arguments)

    // The ".in" files to be used to generate the resource files.
    let inputs = CommandLine.arguments.dropFirst().dropLast().map(URL.init(fileURLWithPath:))

    let outputDirectory = URL.init(fileURLWithPath: CommandLine.arguments.last!)

    // The generated ".out" files that should be copied into the resource bundle
    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    for (i, o) in zip(inputs, outputs) {

      try (String(contentsOf: i, encoding: .utf8) + "\n# PROCESSED!\n")
        .write(to: o, atomically: true, encoding: .utf8)
    }
  }

}
