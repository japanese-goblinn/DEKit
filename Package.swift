// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DEKit",
    dependencies: [],
    targets: [
        .target(
            name: "DEKit",
            dependencies: []),
        .testTarget(
            name: "DEKitTests",
            dependencies: ["DEKit"]),
    ]
)
