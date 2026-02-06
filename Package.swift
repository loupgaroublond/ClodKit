// swift-tools-version: 6.0
// Native Claude Code SDK - Pure Swift implementation

import PackageDescription

let package = Package(
    name: "ClaudeCodeSDK",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ClaudeCodeSDK",
            targets: ["ClaudeCodeSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ClaudeCodeSDK",
            dependencies: []),
        .testTarget(
            name: "ClaudeCodeSDKTests",
            dependencies: ["ClaudeCodeSDK"]),
    ]
)
