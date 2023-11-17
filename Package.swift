// swift-tools-version: 5.8

import PackageDescription

#if os(Windows)
let onWindows = true
#else
let onWindows = false
#endif

let package = Package(
  name: "ResourceGeneration",
  products: [],

  targets: [
    .testTarget(
      name: "ResourceGenerationTests",
      dependencies: ["LibWithResource"]
    ),

    .plugin(
      name: "ResourceGeneratorPlugin", capability: .buildTool(),
      // On Windows the plugin cannot have a dependency on the tool,
      // or building tests that depend (transitively) on the output of
      // the plugin fail to build with link errors about duplicate
      // main functions
      // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716).
      //
      dependencies: onWindows ? [] : ["GenerateResource"]
    ),


    .executableTarget(name: "GenerateResource",
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    .target(
      name: "LibWithResource",
      plugins: ["ResourceGeneratorPlugin"]
    ),

    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithResource"],
      // -parse-as-library is needed to make the @main directive work on Windows.
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),
  ]
)
