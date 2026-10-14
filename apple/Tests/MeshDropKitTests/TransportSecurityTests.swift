import XCTest
import CryptoKit
import Network
@testable import MeshDropKit

final class TransportSecurityTests: XCTestCase {
    func testCertificateProvesExistingIdentityAndRejectsTamperingAndExpiry() throws {
        let identity = Identity(id: "test", privateKey: .init())
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let material = try TransportSecurity.certificate(identity: identity, now: now)
        XCTAssertEqual(try TransportSecurity.verifyCertificate(material.der, now: now), identity.fingerprint)
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(material.der, now: now.addingTimeInterval(31 * 86400)))
        var tampered = material.der
        tampered[tampered.count - 8] ^= 1
        XCTAssertThrowsError(try TransportSecurity.verifyCertificate(tampered, now: now))
    }

    func testMutualTLSAuthenticatesBothPeersAndTransfersText() async throws {
        let server = Identity(id: "server", privateKey: .init())
        let client = Identity(id: "client", privateKey: .init())
        let listener = try NWListener(using: TransportSecurity.parameters(identity: server), on: .any)
        let ready = expectation(description: "listener")
        let received = expectation(description: "encrypted frame")
        let peerReady = expectation(description: "client authenticated server")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { nw in
            let connection = Connection(nwConnection: nw)
            Task {
                await connection.start(onReady: {}, onMessage: { type, body in
                    let fingerprint = await connection.authenticatedFingerprint
                    XCTAssertEqual(fingerprint, client.fingerprint)
                    XCTAssertEqual(body, Data("encrypted test".utf8))
                    received.fulfill()
                    await connection.close()
                }, onClose: { _ in })
            }
        }
        listener.start(queue: .global())
        defer { listener.cancel() }
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(listener.port)
        let parameters = try TransportSecurity.parameters(identity: client, expectedFingerprint: server.fingerprint)
        let nw = NWConnection(host: "127.0.0.1", port: port, using: parameters)
        let connection = Connection(nwConnection: nw)
        await connection.start(onReady: {
            let fingerprint = await connection.authenticatedFingerprint
            XCTAssertEqual(fingerprint, server.fingerprint)
            peerReady.fulfill()
            try? await connection.send(type: MessageType.text, body: Data("encrypted test".utf8))
        }, onMessage: { _, _ in }, onClose: { _ in })
        await fulfillment(of: [peerReady, received], timeout: 10)
        await connection.close()
    }
}

extension TransportSecurityTests {
    func testWrongFingerprintIsRejectedBeforeReady() async throws {
        let server = Identity(id: "server", privateKey: .init())
        let client = Identity(id: "client", privateKey: .init())
        let listener = try NWListener(using: TransportSecurity.parameters(identity: server), on: .any)
        let ready = expectation(description: "listener")
        let closed = expectation(description: "fingerprint rejected")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { nw in
            let connection = Connection(nwConnection: nw)
            Task { await connection.start(onReady: {}, onMessage: { _, _ in }, onClose: { _ in }) }
        }
        listener.start(queue: .global())
        defer { listener.cancel() }
        await fulfillment(of: [ready], timeout: 5)
        let parameters = try TransportSecurity.parameters(identity: client, expectedFingerprint: client.fingerprint)
        let nw = NWConnection(host: "127.0.0.1", port: try XCTUnwrap(listener.port), using: parameters)
        let connection = Connection(nwConnection: nw)
        await connection.start(onReady: { XCTFail("Wrong peer was accepted") }, onMessage: { _, _ in XCTFail("Unauthenticated content delivered") }, onClose: { error in
            XCTAssertNotNil(error)
            closed.fulfill()
        })
        await fulfillment(of: [closed], timeout: 14)
        await connection.close()
    }
}
