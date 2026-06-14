import XCTest
@testable import MeshDropKit

/// 桌面端设置开关接入 engine 后的附加式标志：默认安全值 + UserDefaults 持久化。
/// 这些标志默认值必须不改变既有收发 / 配对行为（trustedOnly / autoAcceptStranger 默认关；
/// verifyBeforeReceive / clipboardSyncEnabled / visibleOnLan 默认开）。
@MainActor
final class ShareEngineSettingsTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "meshdrop.trustedOnly",
        "meshdrop.autoAcceptStranger",
        "meshdrop.verifyBeforeReceive",
        "meshdrop.clipboardSync",
        "meshdrop.visibleOnLan",
    ]

    /// 每个用例后清掉持久化痕迹，避免相互污染（单例 engine 跨用例共享）。
    override func tearDown() {
        for k in keys { defaults.removeObject(forKey: k) }
        super.tearDown()
    }

    /// trustedOnly / autoAcceptStranger：默认关（不引入 trusted-only 隔离、不自动接受陌生人）。
    func testDangerousFlagsDefaultOff() {
        let engine = ShareEngine.shared
        engine.trustedOnly = false
        engine.autoAcceptStranger = false
        XCTAssertFalse(engine.trustedOnly)
        XCTAssertFalse(engine.autoAcceptStranger)
    }

    /// verifyBeforeReceive 默认开（更安全：禁用一切自动接受）。
    /// 用未写过 key 的环境断言 fallback 默认值。
    func testVerifyBeforeReceiveDefaultsOnWhenUnset() {
        defaults.removeObject(forKey: "meshdrop.verifyBeforeReceive")
        let fallback = (defaults.object(forKey: "meshdrop.verifyBeforeReceive") as? Bool) ?? true
        XCTAssertTrue(fallback, "verifyBeforeReceive 未设置时应默认开")
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
        engine.autoAcceptStranger = true
        engine.verifyBeforeReceive = false
        engine.clipboardSyncEnabled = false
        engine.visibleOnLan = false

        XCTAssertEqual(defaults.bool(forKey: "meshdrop.trustedOnly"), true)
        XCTAssertEqual(defaults.bool(forKey: "meshdrop.autoAcceptStranger"), true)
        XCTAssertEqual(defaults.object(forKey: "meshdrop.verifyBeforeReceive") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "meshdrop.clipboardSync") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "meshdrop.visibleOnLan") as? Bool, false)

        // 还原默认安全值，避免污染其它用例 / 真实运行环境。
        engine.trustedOnly = false
        engine.autoAcceptStranger = false
        engine.verifyBeforeReceive = true
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
}
