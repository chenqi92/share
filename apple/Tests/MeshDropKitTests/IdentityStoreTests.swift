import XCTest
import CryptoKit
@testable import MeshDropKit

final class IdentityStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        IdentityStore.reset()
    }

    override func tearDown() {
        IdentityStore.reset()
        super.tearDown()
    }

    func testCreateThenLoadReturnsSameIdentity() {
        let a = IdentityStore.loadOrCreate()
        let b = IdentityStore.loadOrCreate()
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertEqual(a.privateKey.rawRepresentation, b.privateKey.rawRepresentation)
    }

    func testResetGeneratesNewIdentity() {
        let a = IdentityStore.loadOrCreate()
        IdentityStore.reset()
        let b = IdentityStore.loadOrCreate()
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }

    func testFingerprintFormat() {
        let id = IdentityStore.loadOrCreate()
        // 32 hex chars, all lowercase
        XCTAssertEqual(id.fingerprint.count, 32)
        XCTAssertNil(id.fingerprint.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdef").inverted))
    }

    func testMigratesLegacyUserDefaultsIntoKeychain() {
        // 模拟旧版本：UserDefaults 里有身份数据，Keychain 是空的
        let pk = Curve25519.Signing.PrivateKey()
        let oldId = "abcdef1234567890abcdef1234567890"
        let defaults = UserDefaults.standard
        defaults.set(oldId, forKey: "meshdrop.identity.id")
        defaults.set(pk.rawRepresentation, forKey: "meshdrop.identity.privatekey")

        let loaded = IdentityStore.loadOrCreate()
        XCTAssertEqual(loaded.id, oldId)
        XCTAssertEqual(loaded.privateKey.rawRepresentation, pk.rawRepresentation)

        // 迁移后旧位置应被清空
        XCTAssertNil(defaults.string(forKey: "meshdrop.identity.id"))
        XCTAssertNil(defaults.data(forKey: "meshdrop.identity.privatekey"))

        // 再次 load 应仍能从 Keychain 拿到
        let again = IdentityStore.loadOrCreate()
        XCTAssertEqual(again.id, oldId)
        XCTAssertEqual(again.privateKey.rawRepresentation, pk.rawRepresentation)
    }
}
