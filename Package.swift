// swift-tools-version: 5.8

import PackageDescription

// Define a constant to clean up dependency management for SPM bug workarounds (see
// LocalTargetCommandDemoPlugin below).  Swift only allows conditional compilation at statement
// granularity so that becomes very inconvenient otherwise.
#if os(Windows)
let onWindows = true
#else
let onWindows = false
#endif

let package = Package(
  name: "SPMBuildToolSupport",
  products: onWindows
    ? [ .executable(name: "GenerateResource", targets: ["GenerateResource"]) ]
    : [],

  targets: [
    // ----------------- Demonstrates a plugin running an executable target --------------

    // This plugin causes an invocation of the executable GenerateResource target below.
    .plugin(
      name: "LocalTargetCommandDemoPlugin", capability: .buildTool(),
      // On Windows the plugin cannot have a dependency on the tool, or building tests that depend
      // (transitively) on the output of the plugin fail to build with link errors about duplicate
      // main functions
      // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716).  On
      // other platforms the plugin _must_ have a dependency on the tool.
      dependencies: onWindows ? [] : ["GenerateResource"]
    ),

    // The executable target run by the above plugin
    .executableTarget(
      name: "GenerateResource", swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    // The target into whose resource bundle which the result is copied
    .target(
      name: "LibWithResourceGeneratedByLocalTarget",
      plugins: ["LocalTargetCommandDemoPlugin"]
    ),

    // An app that uses the resources in the above library
    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithResourceGeneratedByLocalTarget"],
      // -parse-as-library is needed to make the @main directive work.
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    // ------ Demonstrates a plugin running an executable file with a known path ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "ExecutableFileDemoPlugin", capability: .buildTool()
    ),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSourceGeneratedByExecutableFile",
      plugins: ["ExecutableFileDemoPlugin"]
    ),

    // ------ Demonstrates a plugin running a command by name as if in a shell ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "CommandDemoPlugin", capability: .buildTool()
    ),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSourceGeneratedByCommand",
      plugins: ["CommandDemoPlugin"]
    ),

    // ------ Demonstrates a plugin running a single-file Swift script ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "SwiftScriptDemoPlugin", capability: .buildTool()),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSourceGeneratedBySwiftScript",
      plugins: ["SwiftScriptDemoPlugin"]
    ),

    // ----------------- Demonstrates a plugin running a tool from the Swift toolchain --------------

    // This plugin causes an invocation of the `swiftc` tool
    .plugin(
      name: "SwiftToolchainCommandDemoPlugin", capability: .buildTool()
    ),

    // The target into whose resource bundle which the result is copied
    .target(
      name: "LibWithResourceGeneratedBySwiftToolchainCommand",
      plugins: ["SwiftToolchainCommandDemoPlugin"]
    ),

    // ----------------- Tests that prove this all works. --------------

    .testTarget(
      name: "SPMBuildToolSupportTests",
      dependencies: ["LibWithResourceGeneratedByLocalTarget", "LibWithResourceGeneratedBySwiftToolchainCommand"]
    ),

  ]
)
