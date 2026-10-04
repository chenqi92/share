import CryptoKit
import Network
import XCTest
@testable import MeshDropKit

@MainActor
final class DiscoveryIntegrationTests: XCTestCase {
    func testRediscoveryAndExistingConnectionSurviveListenerRestart() async throws {
        guard ProcessInfo.processInfo.environment["MESHDROP_LAN_TESTS"] == "1" else {
            throw XCTSkip("Set MESHDROP_LAN_TESTS=1 to exercise local Bonjour discovery")
        }
        func identity() -> Identity {
            Identity(id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                     privateKey: Curve25519.Signing.PrivateKey())
        }
        let peer = identity()
        let browser = try Discovery(identity: identity(), displayName: "MeshDrop Discovery Test")
        let receiver = try Discovery(identity: peer, displayName: "MeshDrop Receiver Test")
        defer { browser.stop(); receiver.stop() }

        let connected = expectation(description: "Connected to discovered endpoint")
        let accepted = expectation(description: "Receiver accepted the connection")
        let received = expectation(description: "Connection remains usable after discovery stops")
        receiver.onIncomingConnection = { connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state { accepted.fulfill() }
            }
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { data, _, _, error in
                XCTAssertNil(error)
                XCTAssertEqual(data, Data("ping".utf8))
                received.fulfill()
                connection.cancel()
            }
        }
        try browser.start()
        try receiver.start()
        try await waitUntil { browser.currentDevices.contains { $0.id == peer.id } }
        let device = try XCTUnwrap(browser.currentDevices.first { $0.id == peer.id })
        let endpoint = try XCTUnwrap(device.discoveryEndpoint)
        let connection = NWConnection(to: endpoint, using: .tcp)
        defer { connection.cancel() }
        connection.stateUpdateHandler = { state in
            if case .ready = state { connected.fulfill() }
        }
        connection.start(queue: .main)
        await fulfillment(of: [connected, accepted], timeout: 8)

        receiver.stop()
        connection.send(content: Data("ping".utf8), completion: .contentProcessed { error in
            XCTAssertNil(error)
        })
        await fulfillment(of: [received], timeout: 8)
        try await waitUntil { !browser.currentDevices.contains { $0.id == peer.id } }

        let restarted = try Discovery(identity: peer, displayName: "MeshDrop Receiver Test")
        defer { restarted.stop() }
        try restarted.start()
        try await waitUntil { browser.currentDevices.contains { $0.id == peer.id } }
        XCTAssertNotNil(browser.currentDevices.first { $0.id == peer.id }?.discoveryEndpoint)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(condition(), "Bonjour did not publish the expected device state")
    }
}
