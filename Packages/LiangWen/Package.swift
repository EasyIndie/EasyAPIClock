// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiangWen",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LiangWenCore", targets: ["LiangWenCore"]),
        .library(name: "LiangWenKit", targets: ["LiangWenKit"]),
        .library(name: "LiangWenRuntime", targets: ["LiangWenRuntime"]),
        .executable(name: "liangwen-rules", targets: ["LiangWenRuleTool"]),
    ],
    targets: [
        .target(name: "LiangWenCore"),
        .target(name: "LiangWenRuntime", dependencies: ["LiangWenCore"]),
        .target(name: "LiangWenKit", dependencies: ["LiangWenCore", "LiangWenRuntime"]),
        .executableTarget(name: "LiangWenRuleTool", dependencies: ["LiangWenCore"]),
        .testTarget(name: "LiangWenCoreTests", dependencies: ["LiangWenCore"]),
        .testTarget(name: "LiangWenKitTests", dependencies: ["LiangWenCore", "LiangWenRuntime", "LiangWenKit"]),
        .testTarget(name: "LiangWenRuntimeTests", dependencies: ["LiangWenCore", "LiangWenRuntime"]),
    ]
)
