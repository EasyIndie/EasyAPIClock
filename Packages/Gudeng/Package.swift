// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gudeng",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "GudengCore", targets: ["GudengCore"]),
        .library(name: "GudengKit", targets: ["GudengKit"]),
        .library(name: "GudengRuntime", targets: ["GudengRuntime"]),
        .executable(name: "gudeng-rules", targets: ["GudengRuleTool"]),
    ],
    targets: [
        .target(name: "GudengCore"),
        .target(name: "GudengRuntime", dependencies: ["GudengCore"]),
        .target(name: "GudengKit", dependencies: ["GudengCore", "GudengRuntime"]),
        .executableTarget(name: "GudengRuleTool", dependencies: ["GudengCore"]),
        .testTarget(name: "GudengCoreTests", dependencies: ["GudengCore"]),
        .testTarget(name: "GudengKitTests", dependencies: ["GudengCore", "GudengRuntime", "GudengKit"]),
        .testTarget(name: "GudengRuntimeTests", dependencies: ["GudengCore", "GudengRuntime"]),
    ]
)
