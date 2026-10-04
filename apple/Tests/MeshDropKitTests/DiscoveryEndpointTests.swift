import XCTest
import Network
@testable import MeshDropKit

final class DiscoveryEndpointTests: XCTestCase {
    func testUsesAdvertisedServiceNameInsteadOfDeviceID() throws {
        var record = NWTXTRecord()
        record["v"] = "1"
        record["id"] = String(repeating: "a", count: 32)
        record["name"] = TXTRecord.base64URLEncode(Data("客厅的 Mac".utf8))
        record["os"] = "macos"
        record["fp"] = String(repeating: "b", count: 32)
        record["port"] = "9580"
        let endpoint = NWEndpoint.service(name: "MeshDrop (2)", type: TXTRecord.serviceType,
                                          domain: "local.", interface: nil)
        let device = try XCTUnwrap(TXTRecord.decode(record, endpoint: endpoint))
        XCTAssertEqual(device.name, "客厅的 Mac")
        XCTAssertEqual(device.discoveryEndpoint, endpoint)
        XCTAssertEqual(Connection(connectingTo: device).endpointDescription, String(describing: endpoint))
    }

    func testLegacyDevicesStillResolveByID() {
        let device = Device(id: "legacy", name: "Mac", os: .macos, fingerprint: "fp", port: 9580)
        let endpoint = NWEndpoint.service(name: device.id, type: TXTRecord.serviceType,
                                          domain: "local", interface: nil)
        XCTAssertEqual(Connection(connectingTo: device).endpointDescription, String(describing: endpoint))
    }
}
