// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeshDropKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MeshDropKit", targets: ["MeshDropKit"]),
    ],
    targets: [
        .target(
            name: "MeshDropKit",
            path: "Sources/MeshDropKit"
        ),
        .testTarget(
            name: "MeshDropKitTests",
            dependencies: ["MeshDropKit"],
            path: "Tests/MeshDropKitTests"
        ),
    ]
)
