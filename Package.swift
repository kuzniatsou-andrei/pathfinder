// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Absolute path to the built fff dylib dir, so the dev/test process finds it at
// runtime via an rpath. `#filePath` points at this manifest, i.e. the package root.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

let fffLibDir = packageRoot
    .appendingPathComponent("Vendor/fff/target/release")
    .path

// Absolute include dir for the generated fff C header. Absolute (not relative)
// so editor indexers (SourceKit-LSP/clangd), which may run from a different
// working directory than `swift build`, still resolve `#include "fff.h"`.
let fffIncludeDir = packageRoot
    .appendingPathComponent("Vendor/fff/crates/fff-c/include")
    .path

let package = Package(
    name: "Pathfinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PathfinderApp",
            dependencies: ["PathfinderKit"],
            exclude: ["Info.plist", "Resources"]
        ),
        .target(
            name: "CFffShim",
            cSettings: [
                .unsafeFlags(["-I", fffIncludeDir])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", fffLibDir, "-lfff_c",
                    "-Xlinker", "-rpath", "-Xlinker", fffLibDir
                ])
            ]
        ),
        .target(name: "PathfinderKit", dependencies: ["CFffShim"]),
        .testTarget(name: "PathfinderKitTests", dependencies: ["PathfinderKit"]),
    ]
)
