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
    .testTarget(
      name: "ResourceGenerationTests",
      dependencies: ["LibWithResource"]
    ),

    .plugin(
      name: "LocalTargetCommandDemoPlugin", capability: .buildTool(),
      // This plugin causes an invocation of the executable GenerateResource target.
      //
      // On Windows the plugin cannot have a dependency on the tool, or building tests that depend
      // (transitively) on the output of the plugin fail to build with link errors about duplicate
      // main functions
      // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716).  On
      // other platforms the plugin _must_ have a dependency on the tool.
      dependencies: onWindows ? [] : ["GenerateResource"]
    ),

    .executableTarget(name: "GenerateResource",
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    .target(
      name: "LibWithResource",
      plugins: ["LocalTargetCommandDemoPlugin"]
    ),

    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithResource"],
      // -parse-as-library is needed to make the @main directive work on Windows.
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),
  ]
)
