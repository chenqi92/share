import Foundation
import Network
import Security
import CryptoKit
import SwiftASN1

/// TLS uses a short-lived transport key certified by the existing device identity.
/// Pairing therefore survives certificate renewal without trusting an advertised fingerprint alone.
enum TransportSecurity {
    private static let identityPrefix = "urn:meshdrop:identity:"

    static func parameters(identity: Identity, expectedFingerprint: String? = nil) throws -> NWParameters {
        let material = try certificate(identity: identity)
        guard let cert = SecCertificateCreateWithData(nil, material.der as CFData) else { throw Failure.invalidIdentity }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256
        ]
        guard let key = SecKeyCreateWithData(material.key.x963Representation as CFData, attributes as CFDictionary, nil),
              let local = SecIdentityCreate(nil, cert, key),
              let localIdentity = sec_identity_create(local) else { throw Failure.invalidIdentity }
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv13)
        sec_protocol_options_set_local_identity(options, localIdentity)
        sec_protocol_options_set_peer_authentication_required(options, true)
        sec_protocol_options_set_tls_tickets_enabled(options, false)
        sec_protocol_options_set_tls_resumption_enabled(options, false)
        sec_protocol_options_add_tls_application_protocol(options, "meshdrop/1")
        sec_protocol_options_set_verify_block(options, { metadata, _, complete in
            let fingerprint = peerFingerprint(metadata)
            complete(fingerprint != nil && (expectedFingerprint == nil || fingerprint == expectedFingerprint?.lowercased()))
        }, DispatchQueue.global(qos: .userInitiated))
        return NWParameters(tls: tls, tcp: .init())
    }

    static func peerFingerprint(_ metadata: sec_protocol_metadata_t) -> String? {
        var leaf: Data?
        sec_protocol_metadata_access_peer_certificate_chain(metadata) { certificate in
            if leaf == nil {
                leaf = SecCertificateCopyData(sec_certificate_copy_ref(certificate).takeRetainedValue()) as Data
            }
        }
        return leaf.flatMap { try? verifyCertificate($0) }
    }

    static func certificate(identity: Identity, now: Date = Date()) throws -> (der: Data, key: P256.Signing.PrivateKey) {
        let key = P256.Signing.PrivateKey()
        let before = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970) - 300)
        let after = before.addingTimeInterval(30 * 24 * 3600)
        let signature = try identity.privateKey.signature(for: binding(key.publicKey.x963Representation, before, after))
        let proof = identity.publicKey.rawRepresentation + signature
        let der = try SystemCertificate.make(key: key, commonName: identity.fingerprint,
            notBefore: before, notAfter: after,
            alternativeNames: [(0x86, Data((identityPrefix + proof.base64EncodedString()).utf8))], clientAuth: true)
        return (der, key)
    }

    static func verifyCertificate(_ der: Data, now: Date = Date()) throws -> String {
        let certificate = try SystemCertificate.verify(der, now: now)
        guard certificate.alternativeNames.count == 1,
              let alternative = certificate.alternativeNames.first,
              alternative.identifier == ASN1Identifier(tagWithNumber: 6, tagClass: .contextSpecific),
              case .primitive(let bytes) = alternative.content,
              let uri = String(bytes: bytes, encoding: .ascii), uri.hasPrefix(identityPrefix),
              let proof = Data(base64Encoded: String(uri.dropFirst(identityPrefix.count))), proof.count == 96 else {
            throw Failure.invalidIdentity
        }
        let identityKey = try Curve25519.Signing.PublicKey(rawRepresentation: proof.prefix(32))
        guard identityKey.isValidSignature(proof.suffix(64), for: binding(certificate.publicKey, certificate.notBefore, certificate.notAfter)) else {
            throw Failure.invalidIdentity
        }
        return Identity.computeFingerprint(publicKey: identityKey)
    }

    private static func binding(_ key: Data, _ before: Date, _ after: Date) -> Data {
        Data("MeshDrop TLS identity v1\0".utf8) + key
            + Data("|\(Int64(before.timeIntervalSince1970))|\(Int64(after.timeIntervalSince1970))".utf8)
    }

    enum Failure: LocalizedError {
        case invalidIdentity
        var errorDescription: String? { L10n.t("security.authenticationFailed") }
    }
}
