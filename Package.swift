// swift-tools-version: 6.0
// ClodKit - Pure Swift SDK for Claude Code
// "It's just a turf!"

import PackageDescription

let package = Package(
    name: "ClodKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ClodKit",
            targets: ["ClodKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ClodKit",
            dependencies: []),
        .testTarget(
            name: "ClodKitTests",
            dependencies: ["ClodKit"]),
        .executableTarget(
            name: "SimpleQuery",
            dependencies: ["ClodKit"],
            path: "Examples/SimpleQuery"),
        .executableTarget(
            name: "ToolServer",
            dependencies: ["ClodKit"],
            path: "Examples/ToolServer"),
        .executableTarget(
            name: "HookDemo",
            dependencies: ["ClodKit"],
            path: "Examples/HookDemo"),
        .executableTarget(
            name: "PermissionCallback",
            dependencies: ["ClodKit"],
            path: "Examples/PermissionCallback"),
        .executableTarget(
            name: "StreamingOutput",
            dependencies: ["ClodKit"],
            path: "Examples/StreamingOutput"),
    ]
)
