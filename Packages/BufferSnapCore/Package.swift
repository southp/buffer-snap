// swift-tools-version: 6.0

import PackageDescription

// Pure-Swift app logic shared by the app (and later the widget). No UI frameworks, so `swift test`
// runs it on macOS without a simulator.
let package = Package(
    name: "BufferSnapCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BufferSnapCore", targets: ["BufferSnapCore"])
    ],
    targets: [
        .target(name: "BufferSnapCore"),
        .testTarget(name: "BufferSnapCoreTests", dependencies: ["BufferSnapCore"]),
    ]
)
