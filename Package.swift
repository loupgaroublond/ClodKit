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
    ]
)
