// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pathfinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PathfinderApp", dependencies: ["PathfinderKit"]),
        .target(name: "PathfinderKit"),
        .testTarget(name: "PathfinderKitTests", dependencies: ["PathfinderKit"]),
    ]
)
