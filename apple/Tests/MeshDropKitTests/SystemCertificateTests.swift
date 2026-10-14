import XCTest
import CryptoKit
import Security
import SwiftASN1
@testable import MeshDropKit

final class SystemCertificateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testIdentityProofCannotBeMovedToAnotherKeyOrValidityWindow() throws {
        let material = try TransportSecurity.certificate(identity: .init(id: "device", privateKey: .init()), now: now)
        let original = try SystemCertificate.verify(material.der, now: now)
        let names = try original.alternativeNames.map { node -> (UInt8, Data) in
            guard case .primitive(let bytes) = node.content else { throw TransportSecurity.Failure.invalidIdentity }
            return (0x86, Data(bytes))
        }
        let substituted = try SystemCertificate.make(key: .init(), commonName: "forged", notBefore: original.notBefore,
            notAfter: original.notAfter, alternativeNames: names, clientAuth: true)
        XCTAssertNoThrow(try SystemCertificate.verify(substituted, now: now))
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(substituted, now: now))
        let extended = try SystemCertificate.make(key: material.key, commonName: "forged", notBefore: original.notBefore,
            notAfter: original.notAfter.addingTimeInterval(86400), alternativeNames: names, clientAuth: true)
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(extended, now: now))
        let ambiguous = try SystemCertificate.make(key: material.key, commonName: "ambiguous", notBefore: original.notBefore,
            notAfter: original.notAfter, alternativeNames: names + names, clientAuth: true)
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(ambiguous, now: now))
    }

    func testMalformedDERAndUnsupportedAlgorithmsAreRejected() throws {
        let der = try TransportSecurity.certificate(identity: .init(id: "device", privateKey: .init()), now: now).der
        for invalid in [der + Data([0]), Data(der.dropLast()), Data(der.prefix(40)), Data(repeating: 0, count: 16_385)] {
            XCTAssertThrowsError(try TransportSecurity.verifyCertificate(invalid, now: now))
        }
        var unsupported = der
        let algorithm = Data([0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 4, 3, 2])
        while let range = unsupported.range(of: algorithm) { unsupported[range.upperBound - 1] = 3 }
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(unsupported, now: now))
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(der, now: now.addingTimeInterval(-301)))
    }

    func testDuplicateExtensionRejectedEvenWithValidCertificateSignature() throws {
        let material = try TransportSecurity.certificate(identity: .init(id: "device", privateKey: .init()), now: now)
        func children(_ node: ASN1Node) throws -> [ASN1Node] {
            guard case .constructed(let values) = node.content else { throw TransportSecurity.Failure.invalidIdentity }
            return Array(values)
        }
        let cert = try children(DER.parse(Array(material.der)))
        let tbs = try children(cert[0])
        let extensions = try children(children(tbs[7])[0])
        var modified = DER.Serializer()
        modified.appendConstructedNode(identifier: .sequence) { coder in
            tbs.prefix(7).forEach { coder.serialize($0) }
            coder.serialize(explicitlyTaggedWithTagNumber: 3, tagClass: .contextSpecific) { coder in
                coder.appendConstructedNode(identifier: .sequence) { coder in
                    extensions.forEach { coder.serialize($0) }
                    coder.serialize(extensions.last!)
                }
            }
        }
        let signature = try material.key.signature(for: Data(modified.serializedBytes)).derRepresentation
        var result = DER.Serializer()
        try result.appendConstructedNode(identifier: .sequence) { coder in
            coder.serializeRawBytes(modified.serializedBytes)
            coder.serialize(cert[1])
            try coder.serialize(ASN1BitString(bytes: Array(signature)[...]))
        }
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(Data(result.serializedBytes), now: now))
    }

    func testGeneralizedTimeAndGatewayCertificateAreAcceptedBySystem() throws {
        let future = Date(timeIntervalSince1970: 2_600_000_000)
        let identity = Identity(id: "future", privateKey: .init())
        let material = try TransportSecurity.certificate(identity: identity, now: future)
        XCTAssertEqual(try TransportSecurity.verifyCertificate(material.der, now: future), identity.fingerprint)
        let key = P256.Signing.PrivateKey()
        let gateway = try SystemCertificate.make(key: key, commonName: "meshdrop.local", notBefore: now.addingTimeInterval(-60),
            notAfter: now.addingTimeInterval(86400), alternativeNames: [(0x82, Data("localhost".utf8)), (0x87, Data([127, 0, 0, 1]))], keyEncipherment: true)
        let parsed = try SystemCertificate.verify(gateway, now: now)
        XCTAssertEqual(parsed.publicKey, key.publicKey.x963Representation)
        XCTAssertEqual(parsed.alternativeNames.count, 2)
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(gateway, now: now))
    }
}
