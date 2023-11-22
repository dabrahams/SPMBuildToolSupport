import PackagePlugin
import Foundation

#if os(Windows)
import WinSDK
let osIsWindows = true
#else
let osIsWindows = false
#endif

/// The name of the environment variable containing the executable search path.
private let pathEnvironmentVariable = osIsWindows ? "Path" : "PATH"

/// The separator between elements of the executable search path.
private var pathEnvironmentSeparator: Character = osIsWindows ? ";" : ":"

/// The file extension applied to binary executables
public let executableSuffix = osIsWindows ? ".exe" : ""

/// The name of the file that would be run by a “`swift`” command.
private let swiftExecutableName = "swift" + executableSuffix

/// The environment variables of the running process.
private var envVars: [String: String] { ProcessInfo.processInfo.environment }

private extension URL {

  /// Returns `root` with the additional path component `x` appended.
  static func / (_ root: URL, x: String) -> URL {
    root.appendingPathComponent(x)
  }

}

extension PackagePlugin.PluginContext {

  /// Returns the binary executable file that would be invoked as `command` from the command
  /// line if the executable search path in the environment was `searchPath`, or `nil` if no such
  /// file can be found.
  public func firstBinaryExecutable(
    in searchPath: [URL], invocableAs command: String
  ) -> PackagePlugin.Path? {

    searchPath.lazy.map { $0/(command + executableSuffix) }
      .first(where: { FileManager().isExecutableFile(atPath: $0.path) }).map(\.spmPath)

  }

  // The directories searched for command-line commands having no directory qualification.
  private var executableSearchPath: [URL] {
    (envVars[pathEnvironmentVariable] ?? "")
      .split(separator: pathEnvironmentSeparator)
      .map { URL(fileURLWithPath: String($0)) }
  }

  /// A Swift toolchain executable, if possible from the toolchain executing the current build.
  ///
  /// Throws if no executable tool can be found for the given command.
  public func swiftTool(_ command: String = "swift") throws -> PackagePlugin.Path {
    let path = executableSearchPath

    // Try to identify the current Swift Toolchain/ directory.
    //
    // SwiftPM seems to put a descendant of that directory, with the following suffix, into the
    // executable search path when plugins are run
    let pluginAPISuffix = ["lib", "swift", "pm", "PluginAPI"]

    if let toolchain = path.lazy.compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) }).first
    {
      if let s = firstBinaryExecutable(in: [toolchain/"bin"], invocableAs: command) { return s }
    }
    print("Warning: could not identify current toolchain; looking for \(command) in PATH.")

    if let s = firstBinaryExecutable(in: path, invocableAs: command) { return s }
    print("Warning: could not find swift in PATH; asking SPM for the \(command) tool.")

    return try self.tool(named: command).path
  }

}

extension URL {

  /// Returns a copy of self after removing `possibleSuffix` from the tail of its `pathComponents`,
  /// or returns `nil` if `possibleSuffix` is not a suffix of `pathComponents`.
  fileprivate func sansPathComponentSuffix<
    PossibleSuffix: BidirectionalCollection<String> >(_ possibleSuffix: PossibleSuffix) -> URL?
  {
    var r = self
    var remainingSuffix = possibleSuffix[...]
    while let x = remainingSuffix.popLast() {
      if r.lastPathComponent != x { return nil }
      r.deleteLastPathComponent()
    }
    return r
  }

  /// The representation used by the native filesystem.
  internal var platformString: String {
    self.withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }

}

fileprivate extension PackagePlugin.Target {

  /// The source files.
  var allSourceFiles: [URL] {
    return (self as? PackagePlugin.SourceModuleTarget)?
      .sourceFiles(withSuffix: "").map(\.path.url) ?? []
  }

}

fileprivate extension PackagePlugin.Package {

  /// The source files in this package on which the given executable depends.
  func sourceDependencies(ofTargetNamed targetName: String) throws -> [URL] {
    var result: Set<URL> = []
    let t0 = targets.first { $0.name == targetName }!
    var visitedTargets: Set = [t0.id]

    result.formUnion(t0.allSourceFiles)


    for t1 in t0.recursiveTargetDependencies {
      if visitedTargets.insert(t1.id).inserted {
        result.formUnion(t1.allSourceFiles)
      }
    }
    return Array(result)
  }

}

// Workarounds for SPM's buggy `Path` type on Windows.
//
// SPM `PackagePlugin.Path` uses a representation that—if not repaired before used by a
// `BuildToolPlugin` on Windows—will cause files not to be found.
public extension Path {

  /// A string representation appropriate to the platform.
  var platformString: String {
    #if os(Windows)
    string.withCString(encodedAs: UTF16.self) { pwszPath in
      // Allocate a buffer for the repaired UTF-16.
      let bufferSize = Int(GetFullPathNameW(pwszPath, 0, nil, nil))
      var buffer = Array<UTF16.CodeUnit>(repeating: 0, count: bufferSize)
      // Actually do the repair
      _ = GetFullPathNameW(pwszPath, DWORD(bufferSize), &buffer, nil)
      // Drop the zero terminator and convert back to a Swift string.
      return String(decoding: buffer.dropLast(), as: UTF16.self)
    }
    #else
    string
    #endif
  }

  /// A `URL` referring to the same location.
  var url: URL { URL(fileURLWithPath: platformString) }

  /// A representation of `Self` that works on all platforms.
  var repaired: Self {
    #if os(Windows)
    Path(self.platformString)
    #else
    self
    #endif
  }
}

public extension URL {

  /// A Swift Package Manager-compatible representation.
  var spmPath: Path { Path(self.path) }

  /// Returns `self` with the relative file path `suffix` appended.
  ///
  /// This is a portable version of `self.appending(path:)`, which is only available on recent
  /// macOSes.
  func appendingPath(_ suffix: String) -> URL {

#if os(macOS)
    if #available(macOS 13.0, *) { return self.appending(path: suffix) }
#endif

    return (suffix as NSString).pathComponents
      .reduce(into: self) { $0.appendPathComponent($1) }
  }

}

/// Defines functionality for all plugins having a `buildTool` capability.
public protocol SPMBuildToolPlugin: BuildToolPlugin {

  /// Returns the build commands for `target` in `context`.
  func buildCommands(
    context: PackagePlugin.PluginContext,
    target: PackagePlugin.Target
  ) async throws -> [SPMBuildCommand]

}

extension SPMBuildToolPlugin {

  public func createBuildCommands(context: PluginContext, target: Target) async throws
    -> [PackagePlugin.Command]
  {

    return try await buildCommands(context: context, target: target).map {
      try $0.spmCommand(in: context)
    }

  }

}

public extension SPMBuildCommand.Executable {

  /// A partial translation to SPM plugin inputs of an invocation.
  struct SPMInvocation {
    /// The executable that will actually run.
    let executable: PackagePlugin.Path
    /// The command-line arguments that must precede the ones specified by the caller.
    let argumentPrefix: [String]
    /// The source files that must be added as build dependencies if we want the tool
    /// to be re-run when its sources change.
    let additionalSources: [URL]
  }

  fileprivate func spmInvocation(in context: PackagePlugin.PluginContext) throws -> SPMInvocation {
    switch self {
    case .preInstalled(file: let pathToExecutable):
      return .init(
        executable: pathToExecutable.repaired, argumentPrefix: [], additionalSources: [])

    case .targetInThisPackage(name: let targetName):
      if !osIsWindows {
        return try .init(
          executable: context.tool(named: targetName).path.repaired,
          argumentPrefix: [], additionalSources: [])
      }

      // Instead of depending on context.tool(named:), which demands a declared dependency on the
      // tool, which causes link errors on Windows
      // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716),
      // Invoke swift reentrantly to run the tool.

      let noReentrantBuild = envVars["SPM_BUILD_TOOL_SUPPORT_NO_REENTRANT_BUILD"] != nil
      let packageDirectory = context.package.directory.url

      // Locate the scratch directory for reentrant builds inside the package directory to work
      // around SPM's broken Windows path handling
      let conditionalOptions = noReentrantBuild
        ? [ "--skip-build" ]
        : [
          "--scratch-path",
          (packageDirectory / ".build" / UUID().uuidString).platformString
        ]

      return try .init(
        executable: context.swiftTool(),
        argumentPrefix: [
          "run",
          // Only Macs currently use sandboxing, but nested sandboxes are prohibited, so for future
          // resilience in case Windows gets a sandbox, disable it on these reentrant builds.
          //
          // Currently if we run this code on a Mac, disabling the sandbox on this inner build is
          // enough to allow us to write on the scratchPath, which is outside any _outer_ sandbox.
          // I think that's an SPM bug. If they fix it, we'll need to nest scratchPath in
          // context.workDirectory and add an explicit build step to delete it to keep its contents
          // from being incorporated into the resources of the target we're building.
          "--disable-sandbox",
          "--package-path", packageDirectory.platformString]
          + conditionalOptions
          + [ targetName ],
        additionalSources:
          context.package.sourceDependencies(ofTargetNamed: targetName))
    }
  }
}

fileprivate extension SPMBuildCommand {

  /// Returns a representation of `self` for the result of a `BuildToolPlugin.createBuildCommands`
  /// invocation with the given `context` parameter.
  func spmCommand(in context: PackagePlugin.PluginContext) throws -> PackagePlugin.Command {

    switch self {
    case .buildCommand(
           displayName: let displayName,
           executable: let executable,
           arguments: let arguments,
           environment: let environment,
           inputFiles: let inputFiles,
           outputFiles: let outputFiles,
           pluginSourceFile: let pluginSourceFile):

      let i = try executable.spmInvocation(in: context)

      /// Guess at files that constitute this plugin, the changing of which should cause outputs to be
      /// regenerated (workaround for https://github.com/apple/swift-package-manager/issues/6936).
      let pluginSourceDirectory = URL(fileURLWithPath: pluginSourceFile).deletingLastPathComponent()

      // We could filter out directories, but why bother?
      let pluginSources = try FileManager()
        .subpathsOfDirectory(atPath: pluginSourceDirectory.path)
        .map { pluginSourceDirectory.appendingPath($0) }

      return .buildCommand(
        displayName: displayName,
        executable: i.executable,
        arguments: i.argumentPrefix + arguments,
        environment: environment,
        inputFiles: inputFiles.map(\.repaired) + (pluginSources + i.additionalSources).map(\.spmPath),
        outputFiles: outputFiles.map(\.repaired))

    case .prebuildCommand(
           displayName: let displayName,
           executable: let tool,
           arguments: let arguments,
           environment: let environment,
           outputFilesDirectory: let outputFilesDirectory):

      let i = try tool.spmInvocation(in: context)

      return .prebuildCommand(
        displayName: displayName,
        executable: i.executable,
        arguments: i.argumentPrefix + arguments,
        environment: environment,
        outputFilesDirectory: outputFilesDirectory.repaired)
    }
  }

}


/// A command to run during the build.
public enum SPMBuildCommand {

  /// A command-line tool to be invoked.
  public enum Executable {

    /// The executable target named `name` in this package
    case targetInThisPackage(name: String)

    /// The executable at `file`, an absolute path outside the build directory of the package being
    /// built.
    case preInstalled(file: PackagePlugin.Path)
  }

  /// A command that runs when any of its output files are needed by
  /// the build, but out-of-date.
  ///
  /// An output file is out-of-date if it doesn't exist, or if any
  /// input files have changed since the command was last run.
  ///
  /// - Note: the paths in the list of output files may depend on the list of
  ///   input file paths, but **must not** depend on reading the contents of
  ///   any input files. Such cases must be handled using a `prebuildCommand`.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - executable: The executable invoked to build the output files.
  ///   - arguments: Command-line arguments to be passed to the executable.
  ///   - environment: Environment variable assignments visible to the
  ///     tool.
  ///   - inputFiles: Files on which the contents of output files may depend.
  ///     Any paths passed as `arguments` should typically be passed here as
  ///     well.
  ///   - outputFiles: Files to be generated or updated by the tool.
  ///     Any files recognizable by their extension as source files
  ///     (e.g. `.swift`) are compiled into the target for which this command
  ///     was generated as if in its source directory; other files are treated
  ///     as resources as if explicitly listed in `Package.swift` using
  ///     `.process(...)`.
  ///   - pluginSourceFile: the path to a source file of the SPMBuildToolPlugin; allow the
  ///     default to take effect.
  case buildCommand(
        displayName: String?,
        executable: Executable,
        arguments: [String],
        environment: [String: String] = [:],
        inputFiles: [Path] = [],
        outputFiles: [Path] = [],
        pluginSourceFile: String = #filePath
       )

  /// A command that runs unconditionally before every build.
  ///
  /// Prebuild commands can have a significant performance impact
  /// and should only be used when there would be no way to know the
  /// list of output file paths without first reading the contents
  /// of one or more input files. Typically there is no way to
  /// determine this list without first running the command, so
  /// instead of encoding that list, the caller supplies an
  /// `outputFilesDirectory` parameter, and all files in that
  /// directory after the command runs are treated as output files.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - executable: The executable invoked to build the output files.
  ///   - arguments: Command-line arguments to be passed to the tool.
  ///   - environment: Environment variable assignments visible to the tool.
  ///   - workingDirectory: Optional initial working directory when the tool
  ///     runs.
  ///   - outputFilesDirectory: A directory into which the command writes its
  ///     output files.  Any files there recognizable by their extension as
  ///     source files (e.g. `.swift`) are compiled into the target for which
  ///     this command was generated as if in its source directory; other
  ///     files are treated as resources as if explicitly listed in
  ///     `Package.swift` using `.process(...)`.
  case prebuildCommand(
         displayName: String?,
         executable: Executable,
         arguments: [String],
         environment: [String: String] = [:],
         outputFilesDirectory: Path)

}

private extension Process {

  /// The results of a process run that exited with a nonzero code.
  struct NonzeroExit: Error {

    /// The nonzero exit code of the process run.
    public let terminationStatus: Int32

    /// The contents of the standard output stream.
    public let standardOutput: String

    /// The contents of the standard error stream.
    public let standardError: String

    /// The command-line that triggered the process run.
    public let commandLine: [String]
  }

  /// Runs `executable` with the given command line `arguments` and returns the text written to its
  /// standard output, throwing `NonzeroExit` if the command fails.
  static func commandOutput(
    _ executable: URL, arguments: [String] = []) throws -> String {

    let p = Process()
    let pipes = (standardOutput: Pipe(), standardError: Pipe())
    p.executableURL = executable
    p.arguments = arguments
    p.standardOutput = pipes.standardOutput
    p.standardError = pipes.standardError
    try p.run()
    p.waitUntilExit()

    let outputText = (
      standardOutput: pipes.standardOutput.readUTF8(),
      standardError: pipes.standardError.readUTF8()
    )

    if p.terminationStatus != 0 {
      throw NonzeroExit(
        terminationStatus: p.terminationStatus,
        standardOutput: outputText.standardOutput, standardError: outputText.standardError,
        commandLine: [executable.platformString] + arguments)
    }

    return outputText.standardOutput
  }

}

extension Process.NonzeroExit: CustomStringConvertible {

  var description: String {
    return """
      Process.NonzeroExit (status: \(terminationStatus))
      Command line: \(commandLine.map(String.init(reflecting:)).joined(separator: " "))

        standard output:
        -------------
      \(standardOutput)
        -------------

        standard error:
        -------------
      \(standardError)
        -------------
      """
  }

}

extension Pipe {

  /// Returns the contents decoded as UTF-8, while consuming `self`.
  func readUTF8() -> String {
    String(decoding: fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  }

}
