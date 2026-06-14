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
            path: "Sources/MeshDropKit",
            resources: [
                // 用户可见文案的本地化 catalog（zh-Hans 默认 + en），由 .module bundle 加载。
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "MeshDropKitTests",
            dependencies: ["MeshDropKit"],
            path: "Tests/MeshDropKitTests"
        ),
    ]
)
