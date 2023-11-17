import Foundation

@main
struct GenerateResource {
  static func main() throws {

    print("GenerateResource invocation:",  CommandLine.arguments)
    let inputs = CommandLine.arguments.dropFirst().dropLast()
      .map(URL.init(fileURLWithPath:))

    let outputDirectory = URL.init(fileURLWithPath: CommandLine.arguments.last!)

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
