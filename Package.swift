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
  products: [],

  targets: [
    // ----------------- Demonstrates a plugin running a swift script --------------

    // This plugin runs a swift script to generate .swift files.
    .plugin(name: "SwiftCommandDemoPlugin", capability: .buildTool()),

    // The target into which those generated files are compiled.
    .target(name: "LibWithGeneratedSource", plugins: ["SwiftCommandDemoPlugin"]),

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
      name: "LibWithResource",
      plugins: ["LocalTargetCommandDemoPlugin"]
    ),

    // An app that uses the resources in the above library
    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithResource"],
      // -parse-as-library is needed to make the @main directive work on Windows.
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    // ----------------- Tests that prove this all works. --------------

    .testTarget(
      name: "SPMBuildToolSupportTests",
      dependencies: ["LibWithResource", "LibWithGeneratedSource"]
    ),

  ]
)
