# SPMBuildToolSupport
Provides (and demonstrates) workarounds for Swift Package Manager bugs and limitations.

## What bugs and limitations?

- Bugs:
  - Plugin outputs are not automatically rebuilt when a plugin's source changes
    (https://github.com/apple/swift-package-manager/issues/6936)
  - Plugin outputs are not automatically rebuilt when a plugin's executable changes
    (https://github.com/apple/swift-package-manager/issues/6936)
  - Broken file system path handling on Windows
    (https://github.com/apple/swift-package-manager/issues/6994)
  - If you use a plugin to generate tests or source for an executable, on Windows, SPM will try to
    link the plugin itself into the executable, resulting in “duplicate main” link errors
    (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716).

- Limitations:

  - No easy way to reentrantly invoke SPM from within a build tool plugin, a key to working around
    many of the other bugs and limitations described here.
  - No easy way to find the source files on which an executable product depends.
  - SPM's `Path` type doesn't interoperate well with Foundation's `URL`.
  - The released version of the API docs for build tool plugins is inaccurate and confusing (fixes
    [here](https://github.com/apple/swift-package-manager/pull/6941/files)).

## How do I use this package?

1. Because your SPM build tool plugins [cannot have any dependencies on
   libraries](https://forums.swift.org/t/difficulty-sharing-code-between-swift-package-manager-plugins/61690/10),
   so you must arrange for your plugin's source to include
   [`SPMBuildToolSupport.swift`](SPMBuildToolSupport.swift).  One way to do that if you want to stay
   up-to-date with improvements here, and especially if your project contains multiple plugins, is
   to make this repository a submodule of yours, and symlink the file into each subdirectory of your
   `Plugins/` directory (assuming standard SPM layout).

2. Make your plugin inherit from `SPMBuildToolPlugin` and implement its `buildCommands` method
   (instead of inheriting from `BuildToolPlugin` and implementing `createBuildCommands`).  This
   project contains several examples.  There are three kinds of executables that can run build
   commands:

   - `.targetInThisPackage`: an executable target in the same package as the plugin.
   - `.file`: a specific executable file.
   - `.command`: an executable found in the environment's executable search path,
     given the name you'd use to invoke it in a shell (e.g. "find").

3. To turn a `PackagePlugin.Path` or a `Foundation.URL` into a string that will be recognized by the
   host OS (say, to pass on a command line), use its `.platformString` property.  **Do not use
   `URL`'s other properties (e.g. `.path`) for this purpose, as tempting as it may be**.

4. Avoid naïve path manipulations on a `PackagePlugin.Path` directly, which is buggy on some
   platforms.  Consider using its `url` property and then, if necessary, converting the result back
   to a `PackagePlugin.Path`.
   
5. **On Windows**:
   - In `Package.swift`, omit executable targets in your package from the list of your build tool's
     dependencies.
   - To speed up builds when using `.targetInThisPackage(name:)` commands, set
     `SPM_BUILD_TOOL_SUPPORT_NO_REENTRANT_BUILD=1` in your environment, but always build the targets
     you omitted above *before* anything that depends on the build tools.
