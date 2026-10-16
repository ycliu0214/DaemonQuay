# DaemonQuay Build Requirements

## Tested Build Environment

| Component | Tested configuration |
| --- | --- |
| macOS | 27.0.1 (Build 26A434) |
| Xcode | 27.0 (Build 27A266a) |
| Apple Swift | 6.4 (swiftlang-6.4.0.34.1) |
| Swift Driver | 1.168.6 |
| Build host architecture | Apple Silicon |
| Author's target | arm64-apple-macosx27.0.0 |

These values describe the author's **tested environment**, not the minimum supported versions. The current `Scripts/build.sh` sets the compilation target to `arm64-apple-macosx14.0` and writes `LSMinimumSystemVersion=14.0`; these values are build configuration, not a claim of completed compatibility testing.

## Build-time Tools

- Xcode Command Line Tools, including `xcrun`, `swiftc`, and the macOS SDK.
- `/usr/bin/sips` for icon resizing and `/usr/bin/iconutil` for the `.icns` asset.
- `/usr/bin/codesign` for an ad hoc signature.
- `/bin/zsh` for the build script. Standard shell commands (`cp`, `mkdir`, `rm`, `find`, `chmod`) are used.
- Swift source imports AppKit, SwiftUI, Foundation, Combine, and UniformTypeIdentifiers from the Apple SDK. No external Swift package dependencies are declared by this build script.

From the source directory, run `zsh Scripts/build.sh`. The build output is `build/DaemonQuay.app`. Building removes and recreates that output bundle; it does not modify the user's settings, logs, agents, or service configurations. Do not run an installation or replacement procedure over actively running managed services without reviewing the operational instructions in the README.

The above list concerns building **DaemonQuay only**. oMLX and Caddy are separately managed services, not build dependencies.
