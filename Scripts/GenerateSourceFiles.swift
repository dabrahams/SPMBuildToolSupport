// A command-line script used to generate source files.
import Foundation

struct UsageError: Error, CustomStringConvertible {
  var description: String {
    "Usage: \(CommandLine.arguments.first!) -o <outputDirectory> <inputFiles>..."
  }
}

func main() throws {
  var args = CommandLine.arguments.dropFirst()
  var outputDirectory: URL? = nil
  var inputFiles: [URL] = []

  while let a = args.popFirst() {
    if a == "-o" {
      outputDirectory = args.popFirst().map(URL.init(fileURLWithPath:))
    }
    else {
      inputFiles.append(URL(fileURLWithPath: a))
    }
  }

  if outputDirectory == nil { throw UsageError() }

    // The generated ".swift" files that should be compiled into the target
  let outputFiles = inputFiles.map {
    outputDirectory!.appendingPathComponent($0.deletingPathExtension().lastPathComponent)
  }

  for (i, o) in zip(inputFiles, outputFiles) {

    try (
      "// Comment out the first line, which was " + String(contentsOf: i, encoding: .utf8))
      .write(to: o, atomically: true, encoding: .utf8)
  }
}

do {
  try main()
} catch let e {
  fatalError("\(e)")
}
