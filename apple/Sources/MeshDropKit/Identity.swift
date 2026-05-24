import Foundation
import CryptoKit

/// 设备身份：UUID + Ed25519 长期密钥。指纹 `fp` = SHA-256(pubkey) 的前 16 字节 hex。
///
/// v0.1 骨架阶段把私钥写到 UserDefaults；v1.0 起切到 Keychain（iOS/macOS 都是
/// `kSecClassGenericPassword`，accessible `afterFirstUnlock`）。切换由
/// [security.md](../../../protocol/security.md) 跟踪。
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

/// 持久化封装。先以 UserDefaults 起步，标准的 Keychain 实现见 TODO。
public enum IdentityStore {
    private static let idKey = "meshdrop.identity.id"
    private static let privateKeyKey = "meshdrop.identity.privatekey"

    public static func loadOrCreate() -> Identity {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: idKey),
           let pkData = defaults.data(forKey: privateKeyKey),
           let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: pkData) {
            return Identity(id: id, privateKey: pk)
        }

        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pk = Curve25519.Signing.PrivateKey()
        defaults.set(id, forKey: idKey)
        defaults.set(pk.rawRepresentation, forKey: privateKeyKey)
        return Identity(id: id, privateKey: pk)
    }

    public static func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: idKey)
        defaults.removeObject(forKey: privateKeyKey)
    }
}
