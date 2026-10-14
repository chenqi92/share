import XCTest
@testable import MeshDropKit

final class ReceivePolicyTests: XCTestCase {
    func testOnlyTrustedPeersCanSkipConfirmation() {
        XCTAssertTrue(ReceivePolicy.shouldAutoAccept(isTrusted: true, enabled: true))
        XCTAssertFalse(ReceivePolicy.shouldAutoAccept(isTrusted: false, enabled: true))
        XCTAssertFalse(ReceivePolicy.shouldAutoAccept(isTrusted: true, enabled: false))
        XCTAssertFalse(ReceivePolicy.shouldAutoAccept(isTrusted: false, enabled: false))
    }

    func testMigratesConflictingLegacyDefaultsOnce() {
        withDefaults { defaults in
            defaults.set(false, forKey: "meshdrop.autoAcceptTrusted")
            defaults.set(true, forKey: "meshdrop.verifyBeforeReceive")
            XCTAssertTrue(ReceivePolicy.autoAcceptTrusted(defaults: defaults))
            defaults.set(false, forKey: "meshdrop.autoReceiveTrusted")
            XCTAssertFalse(ReceivePolicy.autoAcceptTrusted(defaults: defaults))
        }
    }

    func testPreservesExplicitLegacyManualChoice() {
        withDefaults { defaults in
            defaults.set(false, forKey: "meshdrop.autoAcceptTrusted")
            defaults.set(false, forKey: "meshdrop.verifyBeforeReceive")
            XCTAssertFalse(ReceivePolicy.autoAcceptTrusted(defaults: defaults))
        }
    }

    func testNewInstallReceivesFromTrustedPeersAutomatically() {
        withDefaults { defaults in
            XCTAssertTrue(ReceivePolicy.autoAcceptTrusted(defaults: defaults))
        }
    }

    private func withDefaults(_ test: (UserDefaults) -> Void) {
        let name = "MeshDrop.ReceivePolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        test(defaults)
    }
}
