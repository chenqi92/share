// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeshDropKit",
    // 库内用户可见文案走 String(localized:bundle:.module)，需声明默认本地化（简体中文）。
    defaultLocalization: "zh-Hans",
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
        // ASN.1 encoding only; cryptography is provided by Apple system frameworks.
        .package(url: "https://github.com/apple/swift-asn1.git", exact: "1.7.3"),
    ],
    targets: [
        .target(
            name: "MeshDropKit",
            dependencies: [
                .product(name: "SwiftASN1", package: "swift-asn1"),
            ],
            path: "Sources/MeshDropKit",
            resources: [
                // 用户可见文案的本地化 catalog（zh-Hans 默认 + en），由 .module bundle 加载。
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "MeshDropKitTests",
            dependencies: ["MeshDropKit"],
            path: "Tests/MeshDropKitTests"
        ),
    ]
)
