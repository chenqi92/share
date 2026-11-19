import Combine
import Network
import XCTest
@testable import MeshDropKit

@MainActor
final class PairingIntegrationTests: XCTestCase {
    func testPairingDecisionsAndReverseFileTransfer() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func engine(_ name: String) -> ShareEngine {
            ShareEngine(identity: Identity(id: name, privateKey: .init()),
                        trustStore: TrustStore(storeURL: root.appendingPathComponent(name + ".trust")),
                        resumeStore: ResumeStore(storeURL: root.appendingPathComponent(name + ".resume")),
                        receiveDirectory: root.appendingPathComponent(name))
        }
        let client = engine("client"), server = engine("server")
        let (outbound, serverDevice) = try await listen(server)
        let (reverse, clientDevice) = try await listen(client)
        defer { outbound.cancel(); reverse.cancel(); client.stop(); server.stop() }

        for decision in [PairingDecision.reject, .allowOnce, .trust] {
            let pending = expectation(description: "receiver presents a single request")
            let subscription = server.$pendingPairings.filter { !$0.isEmpty }.first().sink { _ in pending.fulfill() }
            let done = expectation(description: "pairing handshake finishes")
            var remembered = false
            Task {
                remembered = await client.requestPairing(to: serverDevice)
                done.fulfill()
            }
            await fulfillment(of: [pending], timeout: 5)
            let request = try XCTUnwrap(server.pendingPairings.first)
            XCTAssertEqual(request.peer.fingerprint, client.identity.fingerprint)
            XCTAssertTrue(request.canRemember)
            server.respondToPairing(request.id, decision: decision)
            // A second surface can still deliver a stale tap.
            server.respondToPairing(request.id, decision: .trust)
            await fulfillment(of: [done], timeout: 5)
            XCTAssertEqual(remembered, decision == .trust)
            XCTAssertEqual(client.trusted.map(\.fingerprint), remembered ? [server.identity.fingerprint] : [])
            XCTAssertEqual(server.trusted.map(\.fingerprint), remembered ? [client.identity.fingerprint] : [])
            XCTAssertTrue(client.history.isEmpty && server.history.isEmpty)
            subscription.cancel()
        }
        let persisted = await TrustStore(storeURL: root.appendingPathComponent("client.trust")).snapshot()
        XCTAssertEqual(persisted.map(\.fingerprint), [server.identity.fingerprint])

        let offers = client.$pendingFileOffers.sink { XCTAssertTrue($0.isEmpty) }
        let pairings = client.$pendingPairings.sink { XCTAssertTrue($0.isEmpty) }
        for (name, bytes) in [("sample.txt", Data("reverse transfer".utf8)), ("empty.txt", Data())] {
            let source = root.appendingPathComponent(name)
            try bytes.write(to: source)
            let completed = expectation(description: "receiver confirms \(name)")
            let completion = server.$history.filter { items in
                guard let item = items.first, item.status == .completed,
                      case let .file(filename, _, _) = item.kind else { return false }
                return filename == name
            }.first().sink { _ in completed.fulfill() }
            server.sendFile(to: clientDevice, sourceURL: source)
            await fulfillment(of: [completed], timeout: 8)
            guard case .file(_, _, let url?) = client.history.first?.kind else { return XCTFail("No received file") }
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            completion.cancel()
        }
        withExtendedLifetime((offers, pairings)) {}

    }

    private func listen(_ engine: ShareEngine) async throws -> (NWListener, Device) {
        let parameters = try TransportSecurity.parameters(identity: engine.identity)
        parameters.requiredInterfaceType = .loopback
        let listener = try NWListener(using: parameters)
        let ready = expectation(description: "loopback listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { connection in Task { await engine.acceptIncoming(connection) } }
        listener.start(queue: .global())
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(listener.port)
        return (listener, Device(id: engine.identity.id, name: engine.identity.id, os: .macos,
                                 fingerprint: engine.identity.fingerprint, port: port.rawValue,
                                 discoveryEndpoint: .hostPort(host: "127.0.0.1", port: port)))
    }
}
