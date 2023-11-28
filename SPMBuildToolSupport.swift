import PackagePlugin
import Foundation

#if os(Windows)
import WinSDK
let osIsWindows = true
#else
let osIsWindows = false
#endif

/// The separator between elements of the executable search path.
private var pathEnvironmentSeparator: Character = osIsWindows ? ";" : ":"

/// The environment variables of the running process.
///
/// On platforms where environment variable names are case-insensitive (Windows), the keys have all
/// been normalized to upper case, so looking up a variable value from this dictionary by a name
/// that isn't all-uppercase is a non-portable operation.
private let environmentVariables = osIsWindows ?
  Dictionary(
    uniqueKeysWithValues: ProcessInfo.processInfo.environment.lazy.map {
      x in (key: x.key.uppercased(), value: x.value)
    })
  : ProcessInfo.processInfo.environment


// The directories searched for command-line commands having no directory qualification.
private var executableSearchPath: [URL] {
  (environmentVariables["PATH"] ?? "")
    .split(separator: pathEnvironmentSeparator)
    .map { URL(fileURLWithPath: String($0)) }
}

public extension URL {

  /// Returns `root` with the additional path component `x` appended.
  static func / (_ root: Self, x: String) -> URL {
    root.appendingPathComponent(x)
  }

}

public extension Path {

  /// Returns `root` with the additional path component `x` appended.
  static func / (_ root: Self, x: String) -> Self {
    root.appending([x])
  }

}

extension PackagePlugin.PluginContext {

  func makeScratchDirectory() -> URL {
    for _ in 0..<10 {
      do {
        let d = pluginWorkDirectory.url/UUID().uuidString
        try FileManager().createDirectory(at: d, withIntermediateDirectories: false)
        return d
      }
      catch {}
    }

    fatalError("Could not create a temporary directory after 10 tries.")
  }

  /// Returns the binary executable file that would be invoked as `command` from the command line if
  /// the executable search path in the environment was `searchPath`.
  ///
  /// - Throws if no such binary can be found
  /// - Note: the current directory is only searched if it appears in `searchPath`; it is not
  ///   considered first as in Windows shells.
  func executable(
    invokedAs command: String, searching searchPath: [URL]
  ) throws -> PackagePlugin.Path {
    if !osIsWindows {
      if let r = searchPath.lazy.map({ $0/(command) })
           .first(where: { FileManager().isExecutableFile(atPath: $0.path) }).map(\.spmPath)
      {
        return r
      }
      throw Failure(description: "No executable invoked as \(command) found in: \(searchPath)")
    }

    var subshellEnvironment = ProcessInfo.processInfo.environment
    subshellEnvironment["Path"] = searchPath.map(\.platformString).joined(separator: ";")

    let whereCommand
      = URL(fileURLWithPath: environmentVariables["WINDIR"]!)/"System32"/"where.exe"

    // Use an empty working directory to shield Windows from finding it in the current directory,
    // should it happen to contain an appropriately-named executable.
    let t = makeScratchDirectory()
    defer { _ = try? FileManager().removeItem(at: t) } // ignore if we fail to remove it.

    let p = try Process.commandOutput(
            whereCommand, arguments: [command],
            environment: subshellEnvironment, workingDirectory: t)

    return URL(fileURLWithPath: String(p.prefix { !$0.isNewline})).spmPath
  }

  /// Returns the executable from the current Swift toolchain that could be invoked as `commandName`
  /// from a shell.
  ///
  /// - Warning: only works on Windows, throwing unconditionally on other platforms.
  func swiftToolchainExecutable(invokedAs commandName: String) throws -> PackagePlugin.Path {
    return try executable(invokedAs: commandName, searching: [ toolchainBinDirectory() ])
  }

  /// Returns the current Swift `Toolchain/bin` directory.
  ///
  /// - Warning: only works on Windows, throwing unconditionally on other platforms.
  private func toolchainBinDirectory() throws -> URL {
    // SwiftPM seems to put a descendant of the toolchain directory, with the following suffix, into
    // the executable search path when plugins are run on Windows
    let pluginAPISuffix = ["lib", "swift", "pm", "PluginAPI"]

    // The toolchain directory should have a bin/ directory containing a "swift" executable.
    guard let toolchain = executableSearchPath.lazy
            .compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) })
            .first(where: { (try? executable(invokedAs: "swift", searching: [$0/"bin"])) != nil })
    else {
      throw Failure(description: "Could not locate Swift toolchain bin directory in path.")
    }

    return toolchain/"bin"
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
  public var platformString: String {
    self.withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }

}

public extension PackagePlugin.Target {

  /// The source files.
  var allSourceFiles: [URL] {
    return (self as? PackagePlugin.SourceModuleTarget)?
      .sourceFiles(withSuffix: "").map(\.path.url) ?? []
  }

}

public extension PackagePlugin.Package {

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

    return try await buildCommands(context: context, target: target).flatMap {
      try $0.spmCommands(in: context)
    }

  }

}

private extension SPMBuildCommand.Executable {

  /// A partial translation to SPM plugin inputs of an invocation.
  struct SPMInvocation {

    /// The executable that will actually run.
    let executable: PackagePlugin.Path
    /// The command-line arguments that must precede the ones specified by the caller.
    let argumentPrefix: [String]
    /// The source files that must be added as build dependencies if we want the tool
    /// to be re-run when its sources change.
    let additionalSources: [URL]

    /// Creates an instance with the given properties.
    init(
      executable: PackagePlugin.Path,
      argumentPrefix: [String] = [],
      additionalSources: [URL] = [],
      additionalCommands: [SPMBuildCommand] = []
    )
    {
      self.executable = executable
      self.argumentPrefix = argumentPrefix
      self.additionalSources = additionalSources
    }

  }

  func spmInvocation(in context: PackagePlugin.PluginContext) throws -> SPMInvocation {
    switch self {
    case .file(let p):
      return .init(executable: p.repaired, argumentPrefix: [])

    case .targetInThisPackage(let targetName):
      if !osIsWindows {
        return try .init(executable: context.tool(named: targetName).path.repaired)
      }

      // Instead of depending on context.tool(named:), which demands a declared dependency on the
      // tool, which causes link errors on Windows
      // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716),
      // Invoke swift reentrantly to run the tool.

      let noReentrantBuild
        = environmentVariables["SPM_BUILD_TOOL_SUPPORT_NO_REENTRANT_BUILD"] != nil
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
        executable: try context.swiftToolchainExecutable(invokedAs: "swift"),
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

    case .command(let c):
      return try .init(
        executable: context.executable(invokedAs: c, searching: executableSearchPath))

    case .swiftScript(let s):
      let work = context.pluginWorkDirectory.repaired
      let scratch = work/UUID().uuidString

      // On Windows, SPM doesn't work unless git is in the Path, and we can find a working bash
      // relative to that as part of the git installation.
      let bash = try osIsWindows
        ? context.executable(invokedAs: "git", searching: executableSearchPath)
        .removingLastComponent().removingLastComponent()/"bin"/"bash.exe"
        : context.executable(invokedAs: "bash", searching: executableSearchPath)

      return .init(
        executable: bash,
        argumentPrefix: [
          "-eo", "pipefail", "-c",
          """
            SCRATCH="$1"
            SCRIPT="$2"
            shift 2
            mkdir -p "$SCRATCH"/module-cache
            swiftc -module-cache-path "$SCRATCH"/module-cache "$SCRIPT" -o "$SCRATCH"/runner
            "$SCRATCH"/runner "$@"
            """,
          "ignored", // $0
          scratch.platformString,
          s.platformString,
        ])
    }
  }
}

fileprivate extension SPMBuildCommand {

  /// Returns a representation of `self` for the result of a `BuildToolPlugin.createBuildCommands`
  /// invocation with the given `context` parameter.
  func spmCommands(in context: PackagePlugin.PluginContext) throws -> [PackagePlugin.Command] {

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

      /// Guess at files that constitute this plugin, the changing of which should cause outputs to
      /// be regenerated (workaround for
      /// https://github.com/apple/swift-package-manager/issues/6936).
      let pluginSourceDirectory = URL(fileURLWithPath: pluginSourceFile).deletingLastPathComponent()

      // We could filter out directories, but why bother?
      let pluginSources = try FileManager.default
        .subpathsOfDirectory(atPath: pluginSourceDirectory.platformString)
        .map { pluginSourceDirectory.appendingPath($0) }

      let executableSize = try FileManager
        .default.attributesOfItem(atPath: i.executable.platformString)[FileAttributeKey.size] as! UInt64
      let executableDependency = executableSize == 0 ? [] : [ i.executable.repaired ]
      return [
        .buildCommand(
        displayName: displayName,
        executable: i.executable,
        arguments: i.argumentPrefix + arguments,
        environment: environment,
        inputFiles: inputFiles.map(\.repaired)
          + (pluginSources + i.additionalSources).map(\.spmPath)
      // Work around an SPM bug on Windows: the path to PWSH is some kind of zero-byte shortcut, and SPM
      // complains that it doesn't exist if we try to depend on it.
          + executableDependency,
        outputFiles: outputFiles.map(\.repaired))]

    case .prebuildCommand(
           displayName: let displayName,
           executable: let tool,
           arguments: let arguments,
           environment: let environment,
           outputFilesDirectory: let outputFilesDirectory):

      let i = try tool.spmInvocation(in: context)

      return [.prebuildCommand(
        displayName: displayName,
        executable: i.executable,
        arguments: i.argumentPrefix + arguments,
        environment: environment,
        outputFilesDirectory: outputFilesDirectory.repaired)]
    }
  }

}


/// A command to run during the build.
public enum SPMBuildCommand {

  /// A command-line tool to be invoked.
  public enum Executable {

    /// The executable target in this package, by name
    case targetInThisPackage(String)

    /// An executable file not that exists before the build starts.
    case file(PackagePlugin.Path)

    /// an executable found in the environment's executable search path, given the name you'd use to
    /// invoke it in a shell (e.g. "find").
    case command(String)

    case swiftScript(PackagePlugin.Path)

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
    _ executable: URL, arguments: [String] = [], environment: [String: String]? = nil,
    workingDirectory: URL? = nil
  ) throws -> String {

    let p = Process()
    let pipes = (standardOutput: Pipe(), standardError: Pipe())
    p.executableURL = executable
    p.arguments = arguments
    p.standardOutput = pipes.standardOutput
    p.standardError = pipes.standardError
    p.environment = environment
    p.currentDirectoryURL = workingDirectory
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

private struct Failure: Error, CustomStringConvertible {
  let description: String
}
