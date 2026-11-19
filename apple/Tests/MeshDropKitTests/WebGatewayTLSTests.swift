#if os(macOS)
import CryptoKit
import Foundation
import Security
import XCTest
@testable import MeshDropKit

final class WebGatewayTLSTests: XCTestCase {
    func testDeveloperPairingAndOriginIsolationOverHTTPS() async throws {
        let key = P256.Signing.PrivateKey()
        let der = try SystemCertificate.make(key: key, commonName: "localhost",
            notBefore: Date().addingTimeInterval(-60), notAfter: Date().addingTimeInterval(3600),
            alternativeNames: [(0x87, Data([127, 0, 0, 1]))])
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                          kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                                          kSecAttrKeySizeInBits as String: 256]
        let privateKey = try XCTUnwrap(SecKeyCreateWithData(key.x963Representation as CFData, attributes as CFDictionary, nil))
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
        let identity = try XCTUnwrap(SecIdentityCreate(nil, certificate, privateKey))
        let gateway = WebGateway(config: .init(host: "127.0.0.1", port: 0))
        try gateway.start(identity: identity)
        defer { gateway.stop() }
        for _ in 0..<250 where !gateway.isRunning { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(gateway.isRunning)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: configuration, delegate: PinnedGateway(certificate: der), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        func request(_ path: String, method: String, origin: String) -> URLRequest {
            var req = URLRequest(url: URL(string: "https://127.0.0.1:\(gateway.config.port)/api/v1/\(path)")!)
            req.httpMethod = method
            req.setValue(origin, forHTTPHeaderField: "Origin")
            return req
        }
        let dev = "http://localhost:5173"
        let (_, preflight) = try await session.data(for: request("pair", method: "OPTIONS", origin: dev))
        let cors = try XCTUnwrap(preflight as? HTTPURLResponse)
        XCTAssertEqual(cors.statusCode, 204)
        XCTAssertEqual(cors.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), dev)
        var pair = request("pair", method: "POST", origin: dev)
        pair.httpBody = try JSONSerialization.data(withJSONObject: ["code": gateway.pairingCode])
        let (data, paired) = try await session.data(for: pair)
        XCTAssertEqual((paired as? HTTPURLResponse)?.statusCode, 200)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let token = try XCTUnwrap(object["token"] as? String)

        for (origin, expected) in [(dev, 401), ("https://unrelated.invalid", 403)] {
            var check = request("control", method: "GET", origin: origin)
            check.setValue("meshdrop_session=\(token)", forHTTPHeaderField: "Cookie")
            let (_, response) = try await session.data(for: check)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, expected)
        }
    }
}

private final class PinnedGateway: NSObject, URLSessionDelegate {
    let certificate: Data
    init(certificate: Data) { self.certificate = certificate }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first, SecCertificateCopyData(leaf) as Data == certificate else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
