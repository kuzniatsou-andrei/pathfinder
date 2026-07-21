// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Absolute path to the built fff dylib dir, so the dev/test process finds it at
// runtime via an rpath. `#filePath` points at this manifest, i.e. the package root.
let fffLibDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Vendor/fff/target/release")
    .path

let package = Package(
    name: "Pathfinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PathfinderApp", dependencies: ["PathfinderKit"]),
        .target(
            name: "CFffShim",
            cSettings: [
                .unsafeFlags(["-I", "Vendor/fff/crates/fff-c/include"])
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
