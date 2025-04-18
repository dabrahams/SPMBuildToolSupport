// swift-tools-version: 6.1

import PackageDescription

// Define a constant to clean up dependency management for SPM bug workarounds (see
// CmdTgtPlugin below).  Swift only allows conditional compilation at statement
// granularity so that becomes very inconvenient otherwise.
#if os(Windows)
let onWindows = true
#else
let onWindows = false
#endif

let package = Package(
  name: "SPMBuildToolSupport",
  products: onWindows
    ? [ .executable(name: "GenRsrc", targets: ["GenRsrc"]) ]
    : [],

  targets: [
    // ----------------- Demonstrates a plugin running an executable target --------------

    // This plugin causes an invocation of the executable GenRsrc target below.
    .plugin(
      name: "CmdTgtPlugin", capability: .buildTool(),
      dependencies: ["GenRsrc"]
    ),

    // The executable target run by the above plugin
    .executableTarget(name: "GenRsrc"),

    // The target into whose resource bundle which the result is copied
    .target(
      name: "LibWithRsrcFromLocalTgt",
      // If we don't exclude these, we can use
      //   (target as! SourceModuleTarget).sourceFiles(withSuffix: ".in")
      // to find them, but we will get (incorrect) warnings from SPM about unhandled sources.
      // See CmdTgtPlugin.swift for how to deal with them instead.
      exclude: ["BuildToolPluginInputs"],
      plugins: ["CmdTgtPlugin"]
    ),

    // An app that uses the resources in the above library
    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithRsrcFromLocalTgt"]),

    // ------ Demonstrates a plugin running an executable file with a known path ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "ExecutablePlugin", capability: .buildTool()
    ),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSrcFromExecutable",
      plugins: ["ExecutablePlugin"]
    ),

    // ------ Demonstrates a plugin running a command by name as if in a shell ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "CmdPlugin", capability: .buildTool()
    ),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSrcFromCmd",
      plugins: ["CmdPlugin"]
    ),

    // ------ Demonstrates a plugin running a single-file Swift script ------

    // This plugin invokes one of the scripts in the DemoScripts/ directory.
    .plugin(
      name: "SwiftScriptPlugin", capability: .buildTool()),

    // The target into which the resulting source files are incorporated.
    .target(
      name: "LibWithSrcFromSwiftScript",
      plugins: ["SwiftScriptPlugin"]
    ),

    // ----------------- Demonstrates a plugin running a tool from the Swift toolchain --------------

    // This plugin causes an invocation of the `swiftc` tool
    .plugin(
      name: "SwiftToolchainCmdPlugin", capability: .buildTool()
    ),

    // The target into whose resource bundle which the result is copied
    .target(
      name: "LibWithRsrcFromToolCmd",
      plugins: ["SwiftToolchainCmdPlugin"]
    ),

    // ----------------- Tests that prove this all works. --------------

    .testTarget(
      name: "SPMBuildToolSupportTests",
      dependencies: ["LibWithRsrcFromLocalTgt", "LibWithRsrcFromToolCmd"]
    ),

  ]
)
