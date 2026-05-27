import Foundation
import Security
import OSLog

#if os(macOS)
import Crypto
import X509
import SwiftASN1
import Network
#endif

private let log = Logger(subsystem: "com.welape.meshdrop", category: "GatewayCert")

/// **Web Gateway 自签 TLS 证书** —— 生成 + Keychain 持久化 + 桥接到 NWListener。
///
/// 与 companion-bridges.md §4.3 对齐：CN=`meshdrop.local`，2 年有效期。
/// 用 P-256 (ECDSA-SHA256) — 浏览器兼容性最广，TLS 1.3 baseline。
///
/// 持久化策略：cert DER + P-256 私钥 x963 表示 都存 `kSecClassGenericPassword`
/// （与 Identity 私钥相同 Keychain 类目，accessible `afterFirstUnlock`）。
/// 启动时还原成 `SecIdentity` 喂给 `NWProtocolTLS.Options`。
///
/// **平台**：实装仅 macOS（companion-bridges.md §4.3 规定 Web Gateway 只在
/// macOS / Windows / Linux GUI 上运行）。iOS / tvOS / visionOS 调用会抛
/// `unsupportedPlatform`。
public enum GatewayCertStore {
    private static let service = "com.welape.meshdrop"
    private static let certAccount = "gateway.cert.der"
    private static let keyAccount = "gateway.cert.key.x963"

    /// 加载已有证书；不存在则生成新的并持久化。
    /// 返回 `SecIdentity` —— 可直接 `sec_identity_create()` 给 NWProtocolTLS.Options。
    public static func loadOrCreate(commonName: String = "meshdrop.local") throws -> SecIdentity {
        #if os(macOS)
        if let id = try? loadExisting() {
            log.info("gateway cert: loaded from keychain")
            return id
        }
        log.info("gateway cert: generating new self-signed cert (CN=\(commonName))")
        return try generateAndStore(commonName: commonName)
        #else
        throw CertError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    // MARK: - 生成

    private static func generateAndStore(commonName: String) throws -> SecIdentity {
        let key = P256.Signing.PrivateKey()
        let certKey = Certificate.PrivateKey(key)
        let name = try DistinguishedName { CommonName(commonName) }

        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
            try ExtendedKeyUsage([.serverAuth])
            SubjectAlternativeNames([
                .dnsName(commonName),
                .dnsName("localhost"),
                .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1])),
            ])
        }

        let serial = Certificate.SerialNumber()
        let now = Date()
        let cert = try Certificate(
            version: .v3,
            serialNumber: serial,
            publicKey: certKey.publicKey,
            notValidBefore: now.addingTimeInterval(-60),
            notValidAfter: now.addingTimeInterval(2 * 365 * 24 * 3600),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: certKey
        )

        var serializer = DER.Serializer()
        try serializer.serialize(cert)
        let certDER = Data(serializer.serializedBytes)
        let keyX963 = key.x963Representation

        // 写 Keychain（先删后写避免 duplicate）
        try keychainWrite(account: certAccount, data: certDER)
        try keychainWrite(account: keyAccount, data: keyX963)

        return try buildIdentity(certDER: certDER, keyX963: keyX963)
    }

    // MARK: - 加载

    private static func loadExisting() throws -> SecIdentity {
        guard let certDER = keychainRead(account: certAccount),
              let keyX963 = keychainRead(account: keyAccount) else {
            throw CertError.notFound
        }
        return try buildIdentity(certDER: certDER, keyX963: keyX963)
    }

    /// 把 DER cert + x963 私钥拼成 SecIdentity。
    /// macOS 要求私钥必须能从 keychain 查到才能 `SecIdentityCreateWithCertificate`，
    /// 所以这里先把 SecKey 加进 keychain（用 application-tag 标识）再组合。
    private static func buildIdentity(certDER: Data, keyX963: Data) throws -> SecIdentity {
        // 1. SecCertificate
        guard let cert = SecCertificateCreateWithData(nil, certDER as CFData) else {
            throw CertError.secCertFailed
        }
        // 2. SecKey from x963
        let keyAttrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256,
        ]
        var keyErr: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyX963 as CFData, keyAttrs as CFDictionary, &keyErr) else {
            throw CertError.secKeyFailed(keyErr?.takeRetainedValue())
        }
        // 3. SecItemAdd 私钥到 keychain（每次 app 启动幂等 — duplicate 不报错）
        let addAttrs: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: Data("com.welape.meshdrop.gateway".utf8),
            kSecValueRef as String: secKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let addStatus = SecItemAdd(addAttrs as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            log.warning("SecItemAdd private key returned \(addStatus)")
        }
        // 4. SecIdentityCreateWithCertificate
        var identity: SecIdentity?
        let idStatus = SecIdentityCreateWithCertificate(nil, cert, &identity)
        if idStatus != errSecSuccess || identity == nil {
            throw CertError.identityCreateFailed(idStatus)
        }
        return identity!
    }

    // MARK: - Keychain primitives（generic password 类目）

    private static func keychainRead(account: String) -> Data? {
        var q = baseQuery(account: account)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    private static func keychainWrite(account: String, data: Data) throws -> OSStatus {
        _ = keychainDelete(account: account)
        var attrs = baseQuery(account: account)
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status != errSecSuccess { throw CertError.keychainAddFailed(status) }
        return status
    }

    @discardableResult
    private static func keychainDelete(account: String) -> OSStatus {
        let q = baseQuery(account: account)
        return SecItemDelete(q as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
    #endif // os(macOS)

    // MARK: - 删除（reset）— 跨平台 stub（iOS 等不会触达，但保持 API 对称）

    public static func reset() {
        #if os(macOS)
        _ = keychainDelete(account: certAccount)
        _ = keychainDelete(account: keyAccount)
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data("com.welape.meshdrop.gateway".utf8),
        ]
        SecItemDelete(q as CFDictionary)
        #endif
    }

    // MARK: - Errors

    public enum CertError: Error {
        case notFound
        case secCertFailed
        case secKeyFailed(CFError?)
        case identityCreateFailed(OSStatus)
        case keychainAddFailed(OSStatus)
        case unsupportedPlatform
    }
}
