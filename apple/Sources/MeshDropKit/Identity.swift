import Foundation
import CryptoKit
import Security

/// 设备身份：UUID + Ed25519 长期密钥。指纹 `fp` = SHA-256(pubkey) 的前 16 字节 hex。
///
/// 私钥存储遵循 [security.md](../../../protocol/security.md)：
/// iOS / macOS → Keychain (`kSecClassGenericPassword`，
/// `kSecAttrAccessibleAfterFirstUnlock`)。
public struct Identity: Sendable {
    public let id: String              // 32 hex (UUID 去横线小写)
    public let privateKey: Curve25519.Signing.PrivateKey
    public let publicKey: Curve25519.Signing.PublicKey
    public let fingerprint: String     // 32 hex

    public init(
        id: String,
        privateKey: Curve25519.Signing.PrivateKey
    ) {
        self.id = id
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
        self.fingerprint = Self.computeFingerprint(publicKey: privateKey.publicKey)
    }

    public static func computeFingerprint(publicKey: Curve25519.Signing.PublicKey) -> String {
        let digest = SHA256.hash(data: publicKey.rawRepresentation)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

/// 持久化封装。Keychain 优先；首次启动会自动从 UserDefaults 迁移历史数据。
public enum IdentityStore {
    private static let service = "com.welape.meshdrop"
    private static let idAccount = "identity.id"
    private static let privateKeyAccount = "identity.privatekey"

    // 旧的 UserDefaults key（v0.1 骨架阶段用过），仅作迁移路径保留。
    private static let legacyIDKey = "meshdrop.identity.id"
    private static let legacyPrivateKeyKey = "meshdrop.identity.privatekey"

    public static func loadOrCreate() -> Identity {
        // 1. Keychain hit
        if let idData = keychainRead(account: idAccount),
           let id = String(data: idData, encoding: .utf8),
           let pkData = keychainRead(account: privateKeyAccount),
           let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: pkData) {
            return Identity(id: id, privateKey: pk)
        }

        // 2. UserDefaults 迁移
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: legacyIDKey),
           let pkData = defaults.data(forKey: legacyPrivateKeyKey),
           let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: pkData) {
            // 写入 Keychain
            _ = keychainWrite(account: idAccount, data: Data(id.utf8))
            _ = keychainWrite(account: privateKeyAccount, data: pkData)
            // 旧位置清理
            defaults.removeObject(forKey: legacyIDKey)
            defaults.removeObject(forKey: legacyPrivateKeyKey)
            return Identity(id: id, privateKey: pk)
        }

        // 3. 生成新身份
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pk = Curve25519.Signing.PrivateKey()
        _ = keychainWrite(account: idAccount, data: Data(id.utf8))
        _ = keychainWrite(account: privateKeyAccount, data: pk.rawRepresentation)
        return Identity(id: id, privateKey: pk)
    }

    public static func reset() {
        _ = keychainDelete(account: idAccount)
        _ = keychainDelete(account: privateKeyAccount)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyIDKey)
        defaults.removeObject(forKey: legacyPrivateKeyKey)
    }

    // MARK: - Keychain primitives

    private static func keychainRead(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    private static func keychainWrite(account: String, data: Data) -> OSStatus {
        // 先删后写避免 duplicate
        _ = keychainDelete(account: account)
        var attrs = baseQuery(account: account)
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attrs as CFDictionary, nil)
    }

    @discardableResult
    private static func keychainDelete(account: String) -> OSStatus {
        let query = baseQuery(account: account)
        return SecItemDelete(query as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
