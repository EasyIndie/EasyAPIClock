// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiangWen",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LiangWenCore", targets: ["LiangWenCore"]),
        .library(name: "LiangWenKit", targets: ["LiangWenKit"]),
        .executable(name: "liangwen-rules", targets: ["LiangWenRuleTool"]),
    ],
    targets: [
        .target(name: "LiangWenCore"),
        .target(name: "LiangWenKit", dependencies: ["LiangWenCore"]),
        .executableTarget(name: "LiangWenRuleTool", dependencies: ["LiangWenCore"]),
        .testTarget(name: "LiangWenCoreTests", dependencies: ["LiangWenCore"]),
        .testTarget(name: "LiangWenKitTests", dependencies: ["LiangWenKit"]),
    ]
)
