// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ShareKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ShareKit", targets: ["ShareKit"]),
    ],
    targets: [
        .target(
            name: "ShareKit",
            path: "Sources/ShareKit"
        ),
        .testTarget(
            name: "ShareKitTests",
            dependencies: ["ShareKit"],
            path: "Tests/ShareKitTests"
        ),
    ]
)
