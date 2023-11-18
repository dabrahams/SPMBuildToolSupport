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
      dependencies: ["GenerateResource"]
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
