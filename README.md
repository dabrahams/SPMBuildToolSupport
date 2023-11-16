# SPMBuildToolSupport
Provides (and demonstrates) workarounds for Swift Package Manager bugs and limitations.

## What bugs and limitations?

- Bugs:
  - Plugin outputs are not automatically rebuilt when a plugin's source changes (https://github.com/apple/swift-package-manager/issues/6936)
  - Broken filesystem path handling on Windows (https://github.com/apple/swift-package-manager/issues/6994)
  - If you use a plugin to generate tests or source for an executable, on Windows, SPM will try to link the plugin itself into the executable, resulting in “duplicate main” link errors (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716).

- Limitations:
  - No easy way to reentrantly invoke SPM from within a build tool plugin, a key to working around many of the other bugs and limitations described here.
  - No easy way to find the source files on which an executable product depends.
  - SPM's `Path` type doesn't interoperate well with Foundation's `URL`.
  - The released version of the API docs for build tool plugins is inaccurate and confusing (fixes [here](https://github.com/apple/swift-package-manager/pull/6941/files)).

## How do I use this package?

1. Arrange for your plugin's source to include [`SPMBuildToolSupport.swift`](SPMBuildToolSupport.swift).  One way to do that if you want to stay up-to-date with improvements here, and especially if your project contains multiple plugins, is to make this repository a submodule of yours, and symlink the file into each subdirectory of your `Plugins/` directory (assuming standard SPM layout).
2. Make your plugin inherit from `PortableBuildToolPlugin` and implement its `portableBuildCommands` method (instead of inheriting from `BuildToolPlugin` and implementing `createBuildCommands`).  This project contains several examples.
3. To turn a `PackagePlugin.Path` or a `Foundation.URL` into a string that will be recognized by the host OS (say, to pass on a command line), use its `.filesystemPath` property.  **Do not use `URL`'s other properties (e.g. `.path`) for this purpose, as tempting as it may be**.
4. Avoid naïve path manipulations on a `PackagePlugin.Path` directly, which is buggy on some platforms.  Consider using its `url` property and then, if necessary, converting the result back to a `PackagePlugin.Path`.
5. **On Windows**:
   - In `Package.swift`, omit executable targets in your package from the list of your build tool's dependencies.
   - To speed up builds, set `SPMBuildToolSupport_NO_REENTRANT_BUILD=1` in your environment, but always build the targets you omitted above *before* anything that depends on the build tools.  There are examples of how this works in this project's tests.
