import XCTest
import Network
@testable import MeshDropKit

final class DeviceRoutesTests: XCTestCase {
    private func peer() -> Device {
        Device(id: String(repeating: "a", count: 32), name: "Phone", os: .ios,
               fingerprint: String(repeating: "b", count: 32), port: 1)
    }

    func testSameFingerprintMergesRoutesAcrossRuntimeIDs() throws {
        var lan = peer()
        lan.discoveryEndpoint = .hostPort(host: "192.168.1.2", port: 1)
        var direct = Device(id: "new-runtime", name: "Phone", os: .ios, fingerprint: lan.fingerprint.uppercased(), port: 2)
        direct.peerToPeerEndpoint = .service(name: "Phone", type: Discovery.peerToPeerServiceType, domain: "local", interface: nil)
        var bluetooth = peer()
        bluetooth.bluetoothID = UUID()
        bluetooth.bluetoothPSM = 129
        let merged = DeviceRoutes.merge([[lan], [direct], [bluetooth]], preference: .automatic)
        XCTAssertEqual(merged.count, 1)
        let device = try XCTUnwrap(merged.first)
        XCTAssertEqual(device.availableRoutes, [.lan, .peerToPeer, .bluetooth])
        XCTAssertEqual(DeviceRoutes.select(device, preference: .bluetooth), .bluetooth)
        XCTAssertEqual(DeviceRoutes.select(device, preference: .peerToPeer), .peerToPeer)
        XCTAssertEqual(DeviceRoutes.select(device, preference: .automatic), .lan)
    }

    func testForcedRouteNeverFallsBackToLANAndRemovedRouteDisappears() {
        var lan = peer()
        lan.discoveryEndpoint = .hostPort(host: "192.168.1.2", port: 1)
        XCTAssertNil(DeviceRoutes.select(lan, preference: .bluetooth))
        XCTAssertNil(DeviceRoutes.select(lan, preference: .peerToPeer))
        XCTAssertTrue(DeviceRoutes.merge([[lan], []], preference: .bluetooth).isEmpty)
        XCTAssertEqual(DeviceRoutes.merge([[lan], []], preference: .automatic).count, 1)
    }

    func testHistoryRetryResolvesCurrentBluetoothAndDirectEndpointsAfterRestart() throws {
        let item = HistoryItem(peer: peer(), direction: .outgoing, kind: .text("retry"), status: .failed("offline"))
        let snapshot = try JSONDecoder().decode(HistoryItem.self, from: JSONEncoder().encode(item)).peer
        XCTAssertTrue(snapshot.availableRoutes.isEmpty)
        var current = Device(id: "new-runtime-id", name: "Phone", os: .ios,
                             fingerprint: snapshot.fingerprint.uppercased(), port: 1)
        current.bluetoothID = UUID()
        current.bluetoothPSM = 193
        current.peerToPeerEndpoint = .service(name: current.id, type: Discovery.peerToPeerServiceType, domain: "local", interface: nil)
        let resolved = try XCTUnwrap(DeviceRoutes.currentDevice(for: snapshot, in: [current]))
        XCTAssertEqual(resolved.id, current.id)
        XCTAssertEqual(resolved.bluetoothPSM, 193)
        XCTAssertEqual(DeviceRoutes.select(resolved, preference: .bluetooth), .bluetooth)
        XCTAssertEqual(DeviceRoutes.select(resolved, preference: .peerToPeer), .peerToPeer)
        XCTAssertNil(DeviceRoutes.currentDevice(for: snapshot, in: []))
        let unrelated = Device(id: snapshot.id, name: "Phone", os: .ios, fingerprint: String(repeating: "c", count: 32), port: 1)
        XCTAssertNil(DeviceRoutes.currentDevice(for: snapshot, in: [unrelated]))
    }

    func testDirectConnectionWithoutAWDLEndpointFailsWithoutOpeningLAN() async {
        var device = peer()
        device.discoveryEndpoint = .hostPort(host: "127.0.0.1", port: 1)
        let closed = expectation(description: "unavailable direct route")
        let connection = Connection(connectingTo: device, route: .peerToPeer)
        await connection.start(onReady: { XCTFail("must not use LAN") }, onMessage: { _, _ in }, onClose: { error in
            guard let error = error as? ConnectionError, case .routeUnavailable = error else {
                XCTFail("unexpected error: \(String(describing: error))")
                closed.fulfill()
                return
            }
            closed.fulfill()
        })
        await fulfillment(of: [closed], timeout: 1)
    }

    #if os(iOS) || os(macOS)
    func testBluetoothMetadataValidation() throws {
        let peer = peer()
        let id = UUID()
        let valid = BluetoothAdvertisement(id: peer.id, name: peer.name, os: peer.os, model: nil,
                                           fingerprint: peer.fingerprint, psm: 129, version: 1)
        let restored = try JSONDecoder().decode(BluetoothAdvertisement.self, from: JSONEncoder().encode(valid))
        XCTAssertEqual(restored.device(peripheralID: id)?.bluetoothID, id)
        XCTAssertEqual(restored.device(peripheralID: id)?.bluetoothPSM, 129)
        for invalid in [
            BluetoothAdvertisement(id: peer.id, name: peer.name, os: .ios, model: nil, fingerprint: "invalid", psm: 129, version: 1),
            BluetoothAdvertisement(id: peer.id, name: peer.name, os: .ios, model: nil, fingerprint: peer.fingerprint, psm: 0, version: 1),
            BluetoothAdvertisement(id: peer.id, name: peer.name, os: .ios, model: nil, fingerprint: peer.fingerprint, psm: 129, version: 2)
        ] { XCTAssertNil(invalid.device(peripheralID: id)) }
    }
    #endif
}
