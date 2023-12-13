# SPMBuildToolSupport

This code allows your build tool plugins to easily and portably run executable targets, executable
files by their path, commands that can be invoked from a shell, or Swift script files.

This package provides (and demonstrates) workarounds for Swift Package Manager bugs and limitations.

## What bugs and limitations?

This is just a partial list:

- Bugs:
  - Plugin outputs are not automatically rebuilt when a plugin's executable changes ([SPM issue
    #6936](https://github.com/apple/swift-package-manager/issues/6936))
  - Broken file system path handling on Windows ([SPM issue
    #6994](https://github.com/apple/swift-package-manager/issues/6994))
  - If you use a plugin to generate tests or source for an executable, on Windows, SPM will try to
    link the plugin itself into the executable, resulting in “duplicate main” link errors ([SPM issue
    #6859](https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716)).
  - `swift SomeFile.swift` doesn't work on Windows.
  
- Limitations:

  - No easy way to reentrantly invoke SPM from within a build tool plugin, a key to working around
    many of the other bugs and limitations described here.
  - No easy way to find the source files on which an executable product depends.
  - SPM's `Path` type doesn't interoperate well with Foundation's `URL`.
  - The released version of the API docs for build tool plugins is inaccurate and confusing (fixes
    [here](https://github.com/apple/swift-package-manager/pull/6941/files)).

**Note:** Plugin outputs are not automatically rebuilt when a plugin's source changes ([SPM issue
    #6936](https://github.com/apple/swift-package-manager/issues/6936)).  We don't have a workaround
    for this problem.

## How do I use this package?

1. SPM build tool plugins [cannot have any dependencies on
   libraries](https://forums.swift.org/t/difficulty-sharing-code-between-swift-package-manager-plugins/61690/10),
   so you must arrange for your plugin's source to include
   [`SPMBuildToolSupport.swift`](SPMBuildToolSupport.swift).  One way to do that if you want to stay
   up-to-date with improvements here, and especially if your project contains multiple plugins, is
   to make this repository a submodule of yours, and symlink the file into each subdirectory of your
   `Plugins/` directory (assuming standard SPM layout).

2. Make your plugin inherit from `SPMBuildToolPlugin` and implement its `buildCommands` method
   (instead of inheriting from `BuildToolPlugin` and implementing `createBuildCommands`).  This
   project contains [several examples](https://github.com/dabrahams/SPMBuildToolSupport/tree/main/Plugins).
   Executables that can run build commands are divided into the following cases:

   - `.targetInThisPackage`: an executable target in the same package as the plugin.
   - `.file`: a specific executable file.
   - `.command`: an executable found in the environment's executable search path,
     given the name you'd use to invoke it in a shell (e.g. "find").
   - `.swiftScript`: the executable produced by building a single specific `.swift` file, almost as
     though the file was passed as a parameter to the `swift` command.
   - `.swiftToolchainCommand`: an executable from the currently-running Swift toolchain, given the
     name you'd use to invoke it in a shell (e.g. "swift", "swiftc", "clang").


4. To turn a `PackagePlugin.Path` or a `Foundation.URL` into a string that will be recognized by the
   host OS (say, to pass on a command line), use its `.platformString` property.  **Do not use
   `URL`'s other properties (e.g. `.path`) for this purpose, as tempting as it may be**.

5. Avoid naïve path manipulations on a `PackagePlugin.Path` directly, which is buggy on some
   platforms.  Consider using its `url` property and then, if necessary, converting the result back
   to a `PackagePlugin.Path`.

6. To avoid spurious warnings from SPM about unhandled sources, do not use SPM's
   `.sourceFiles(withSuffix: ".in")` to find the input files to your build plugin.  Instead,
   [exclude them from the
   target](https://github.com/dabrahams/SPMBuildToolSupport/blob/48d0253/Package.swift#L45) in
   `Package.swift` and in your plugin, locate them relative to other directories in your
   project. [`LocalTargetCommandDemoPlugin.swift`](https://github.com/dabrahams/SPMBuildToolSupport/blob/48d0253/Plugins/LocalTargetCommandDemoPlugin/LocalTargetCommandDemoPlugin.swift#L11-L14)
   shows an example.

7. **On Windows**:
   - In `Package.swift`, [omit executable targets in your package](https://github.com/dabrahams/SPMBuildToolSupport/blob/150f67fc2c08d1f13c143c9e2c31e4c9070b09a6/Package.swift#L31) from the list of your build tool's
     dependencies.
   - To speed up builds when using `.targetInThisPackage(name:)`:
	 1. Make sure all the targets omitted above have [a corresponding `.product` of the same name](https://github.com/dabrahams/SPMBuildToolSupport/blob/150f67fc2c08d1f13c143c9e2c31e4c9070b09a6/Package.swift#L17) in your package.
	 2. [set `SPM_BUILD_TOOL_SUPPORT_NO_REENTRANT_BUILD=1`](https://github.com/dabrahams/SPMBuildToolSupport/blob/150f67fc2c08d1f13c143c9e2c31e4c9070b09a6/.github/workflows/build-and-test.yml#L92) in your environment
	 3. Build those products in a [separate build step](https://github.com/dabrahams/SPMBuildToolSupport/blob/150f67fc2c08d1f13c143c9e2c31e4c9070b09a6/.github/workflows/build-and-test.yml#L93) *before* [building anything that depends on the build tools](https://github.com/dabrahams/SPMBuildToolSupport/blob/150f67fc2c08d1f13c143c9e2c31e4c9070b09a6/.github/workflows/build-and-test.yml#L94) that use them.

