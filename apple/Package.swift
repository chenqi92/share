// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeshDropKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MeshDropKit", targets: ["MeshDropKit"]),
    ],
    dependencies: [
        // swift-certificates 用于 Web Gateway TLS 1.3 自签证书生成（companion-bridges §4.3）。
        // 拖入 swift-asn1 + swift-crypto（均 Apple 官方纯 Swift）。
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "MeshDropKit",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
            ],
            path: "Sources/MeshDropKit"
        ),
        .testTarget(
            name: "MeshDropKitTests",
            dependencies: ["MeshDropKit"],
            path: "Tests/MeshDropKitTests"
        ),
    ]
)
