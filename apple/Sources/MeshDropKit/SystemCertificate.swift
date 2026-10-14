import Foundation
import CryptoKit
import Security
import SwiftASN1

/// MeshDrop's self-signed P-256 certificate profile. Cryptographic operations use CryptoKit;
/// SwiftASN1 only decodes DER. This is not a general-purpose certificate trust evaluator.
enum SystemCertificate {
    struct Verified {
        let publicKey: Data
        let notBefore: Date
        let notAfter: Date
        let alternativeNames: [ASN1Node]
    }

    private static let signatureAlgorithm = sequence(oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02]))
    private static let keyAlgorithm = sequence(
        oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01]),
        oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07]))

    static func make(key: P256.Signing.PrivateKey, commonName: String, notBefore: Date, notAfter: Date,
                     alternativeNames: [(tag: UInt8, bytes: Data)], clientAuth: Bool = false,
                     keyEncipherment: Bool = false) throws -> Data {
        guard notBefore < notAfter, !alternativeNames.isEmpty,
              commonName.utf8.count <= 256 else { throw TransportSecurity.Failure.invalidIdentity }
        let name = sequence(tlv(0x31, sequence(oid([0x55, 0x04, 0x03]), tlv(0x0c, Data(commonName.utf8)))))
        var serial = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, serial.count, &serial) == errSecSuccess else {
            throw TransportSecurity.Failure.invalidIdentity
        }
        serial[0] = (serial[0] & 0x7f) | 0x01
        var purposes = oid([0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01])
        if clientAuth { purposes += oid([0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x02]) }
        let extensions = sequence(
            ext(19, critical: true, value: sequence()),
            ext(15, critical: true, value: tlv(0x03, Data(keyEncipherment ? [5, 0xa0] : [7, 0x80]))),
            ext(37, value: tlv(0x30, purposes)),
            ext(17, value: tlv(0x30, alternativeNames.reduce(into: Data()) { $0 += tlv($1.tag, $1.bytes) })))
        let tbs = sequence(tlv(0xa0, tlv(0x02, Data([2]))), tlv(0x02, Data(serial)), signatureAlgorithm,
                           name, sequence(try time(notBefore), try time(notAfter)), name,
                           sequence(keyAlgorithm, tlv(0x03, Data([0]) + key.publicKey.x963Representation)),
                           tlv(0xa3, extensions))
        let signature = try key.signature(for: tbs).derRepresentation
        return sequence(tbs, signatureAlgorithm, tlv(0x03, Data([0]) + signature))
    }

    static func verify(_ der: Data, now: Date) throws -> Verified {
        guard der.count <= 16_384 else { throw TransportSecurity.Failure.invalidIdentity }
        let certificate = try children(DER.parse(Array(der)), count: 3)
        let tbs = try children(certificate[0], count: 8)
        guard Data(certificate[1].encodedBytes) == signatureAlgorithm,
              Data(tbs[2].encodedBytes) == signatureAlgorithm,
              Data(tbs[0].encodedBytes) == Data([0xa0, 3, 2, 1, 2]),
              tbs[1].identifier == .integer,
              tbs[3].identifier == .sequence,
              tbs[3].encodedBytes == tbs[5].encodedBytes else { throw TransportSecurity.Failure.invalidIdentity }
        let validity = try children(tbs[4], count: 2)
        let before = try date(validity[0]), after = try date(validity[1])
        guard before <= now, now < after else { throw TransportSecurity.Failure.invalidIdentity }
        let spki = try children(tbs[6], count: 2)
        guard Data(spki[0].encodedBytes) == keyAlgorithm else { throw TransportSecurity.Failure.invalidIdentity }
        let publicKey = try bitString(spki[1])
        let key = try P256.Signing.PublicKey(x963Representation: publicKey)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: bitString(certificate[2]))
        guard key.isValidSignature(signature, for: Data(certificate[0].encodedBytes)),
              let secCert = SecCertificateCreateWithData(nil, der as CFData),
              let secKey = SecCertificateCopyKey(secCert),
              let secBytes = SecKeyCopyExternalRepresentation(secKey, nil) as Data?,
              secBytes == publicKey else { throw TransportSecurity.Failure.invalidIdentity }

        let wrapper = try children(tbs[7], identifier: .init(tagWithNumber: 3, tagClass: .contextSpecific), count: 1)
        let extensions = try children(wrapper[0])
        guard extensions.count <= 10 else { throw TransportSecurity.Failure.invalidIdentity }
        var seen = Set<ASN1ObjectIdentifier>()
        var alternatives: [ASN1Node]?
        for node in extensions {
            let fields = try children(node)
            guard fields.count == 2 || fields.count == 3 else { throw TransportSecurity.Failure.invalidIdentity }
            let id = try ASN1ObjectIdentifier(derEncoded: fields[0])
            guard seen.insert(id).inserted else { throw TransportSecurity.Failure.invalidIdentity }
            let critical = fields.count == 3 ? try Bool(derEncoded: fields[1]) : false
            let value = try ASN1OctetString(derEncoded: fields[fields.count - 1])
            let body = try DER.parse(value.bytes)
            switch id {
            case [2, 5, 29, 17]: alternatives = try children(body)
            case [2, 5, 29, 19]:
                guard try children(body).isEmpty else { throw TransportSecurity.Failure.invalidIdentity }
            case [2, 5, 29, 15]:
                // The transport profile only permits signing; the browser gateway also permits encipherment.
                guard body.encodedBytes == [3, 2, 7, 0x80] || body.encodedBytes == [3, 2, 5, 0xa0] else {
                    throw TransportSecurity.Failure.invalidIdentity
                }
            case [2, 5, 29, 37]:
                let purposes = try children(body).map { try ASN1ObjectIdentifier(derEncoded: $0) }
                guard !purposes.isEmpty, purposes.allSatisfy({ $0 == [1, 3, 6, 1, 5, 5, 7, 3, 1] || $0 == [1, 3, 6, 1, 5, 5, 7, 3, 2] }) else {
                    throw TransportSecurity.Failure.invalidIdentity
                }
            default:
                guard !critical else { throw TransportSecurity.Failure.invalidIdentity }
            }
        }
        guard let alternatives else { throw TransportSecurity.Failure.invalidIdentity }
        return Verified(publicKey: publicKey, notBefore: before, notAfter: after, alternativeNames: alternatives)
    }

    private static func children(_ node: ASN1Node, identifier: ASN1Identifier = .sequence, count: Int? = nil) throws -> [ASN1Node] {
        guard node.identifier == identifier, case .constructed(let nodes) = node.content else {
            throw TransportSecurity.Failure.invalidIdentity
        }
        let result = Array(nodes)
        guard count == nil || result.count == count else { throw TransportSecurity.Failure.invalidIdentity }
        return result
    }

    private static func bitString(_ node: ASN1Node) throws -> Data {
        let bits = try ASN1BitString(derEncoded: node)
        guard bits.paddingBits == 0 else { throw TransportSecurity.Failure.invalidIdentity }
        return Data(bits.bytes)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(_ node: ASN1Node) throws -> Date {
        let parts: DateComponents
        if node.identifier == .utcTime {
            let value = try UTCTime(derEncoded: node)
            parts = DateComponents(year: value.year, month: value.month, day: value.day,
                                   hour: value.hours, minute: value.minutes, second: value.seconds)
        } else {
            let value = try GeneralizedTime(derEncoded: node)
            guard value.fractionalSeconds == 0 else { throw TransportSecurity.Failure.invalidIdentity }
            parts = DateComponents(year: value.year, month: value.month, day: value.day,
                                   hour: value.hours, minute: value.minutes, second: value.seconds)
        }
        guard let result = calendar.date(from: parts) else { throw TransportSecurity.Failure.invalidIdentity }
        return result
    }

    private static func time(_ date: Date) throws -> Data {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var serializer = DER.Serializer()
        if (1950...2049).contains(parts.year!) {
            try serializer.serialize(UTCTime(year: parts.year!, month: parts.month!, day: parts.day!,
                                            hours: parts.hour!, minutes: parts.minute!, seconds: parts.second!))
        } else {
            try serializer.serialize(GeneralizedTime(year: parts.year!, month: parts.month!, day: parts.day!,
                                                    hours: parts.hour!, minutes: parts.minute!, seconds: parts.second!, fractionalSeconds: 0))
        }
        return Data(serializer.serializedBytes)
    }

    // Only locally constructed values reach this encoder; untrusted input goes through DER.parse.
    private static func tlv(_ tag: UInt8, _ value: Data) -> Data {
        var length = value.count
        var bytes = [UInt8]()
        if length < 128 { bytes = [UInt8(length)] }
        else {
            while length > 0 { bytes.insert(UInt8(length & 255), at: 0); length >>= 8 }
            bytes.insert(0x80 | UInt8(bytes.count), at: 0)
        }
        return Data([tag] + bytes) + value
    }
    private static func sequence(_ values: Data...) -> Data { tlv(0x30, values.reduce(Data(), +)) }
    private static func oid(_ bytes: [UInt8]) -> Data { tlv(0x06, Data(bytes)) }
    private static func ext(_ number: UInt8, critical: Bool = false, value: Data) -> Data {
        tlv(0x30, oid([0x55, 0x1d, number]) + (critical ? Data([1, 1, 0xff]) : Data()) + tlv(0x04, value))
    }
}
