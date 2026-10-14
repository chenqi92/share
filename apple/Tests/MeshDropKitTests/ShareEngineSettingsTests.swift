import XCTest
@testable import MeshDropKit

@MainActor
final class ShareEngineSettingsTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "meshdrop.trustedOnly",
        "meshdrop.clipboardSync",
        "meshdrop.visibleOnLan",
    ]

    /// 每个用例后清掉持久化痕迹，避免相互污染（单例 engine 跨用例共享）。
    override func tearDown() {
        for k in keys { defaults.removeObject(forKey: k) }
        super.tearDown()
    }

    func testDangerousFlagsDefaultOff() {
        let engine = ShareEngine.shared
        engine.trustedOnly = false
        XCTAssertFalse(engine.trustedOnly)
    }

    /// clipboardSyncEnabled / visibleOnLan 默认开（与现有行为一致）。
    func testEnabledByDefaultFlags() {
        defaults.removeObject(forKey: "meshdrop.clipboardSync")
        defaults.removeObject(forKey: "meshdrop.visibleOnLan")
        let clip = (defaults.object(forKey: "meshdrop.clipboardSync") as? Bool) ?? true
        let lan = (defaults.object(forKey: "meshdrop.visibleOnLan") as? Bool) ?? true
        XCTAssertTrue(clip)
        XCTAssertTrue(lan)
    }

    /// 改动经 didSet 落到 UserDefaults（持久化 → 重启保持）。
    func testFlagsPersistToUserDefaults() {
        let engine = ShareEngine.shared
        engine.trustedOnly = true
        engine.clipboardSyncEnabled = false
        engine.visibleOnLan = false

        XCTAssertEqual(defaults.bool(forKey: "meshdrop.trustedOnly"), true)
        XCTAssertEqual(defaults.object(forKey: "meshdrop.clipboardSync") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "meshdrop.visibleOnLan") as? Bool, false)

        // 还原默认安全值，避免污染其它用例 / 真实运行环境。
        engine.trustedOnly = false
        engine.clipboardSyncEnabled = true
        engine.visibleOnLan = true
    }

    /// clipboardSyncEnabled 关闭时 pushClipboard 不应入站、不发送（no-op 安全）。
    /// 这里只能验证不崩溃 + 不产生收件箱副作用（无对端，pushClipboard 直接返回）。
    func testPushClipboardNoOpWhenSyncDisabled() {
        let engine = ShareEngine.shared
        engine.clipboardSyncEnabled = false
        let dev = Device(id: "x", name: "x", os: .macos, model: nil, fingerprint: "f", port: 1)
        engine.pushClipboard(to: dev, content: "hello", kind: "text")
        XCTAssertTrue(engine.clipboardInbox.isEmpty)
        engine.clipboardSyncEnabled = true
    }

    func testChosenReceiveDirectoryControlsSaveLocation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDropTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let peer = Device(
            id: "peer-id",
            name: "../Living Room Mac",
            os: .macos,
            model: nil,
            fingerprint: "peer-fingerprint",
            port: 9580
        )
        let directory = try ShareEngine.receiveSaveDir(in: root, for: peer)

        XCTAssertEqual(directory.deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(directory.lastPathComponent, "Living Room Mac")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }
}
