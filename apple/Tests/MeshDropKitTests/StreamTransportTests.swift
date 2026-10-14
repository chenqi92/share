import XCTest
import CoreFoundation
@testable import MeshDropKit

@MainActor
final class StreamTransportTests: XCTestCase {
    func testHeartbeatWaitsFullIntervalBetweenRetries() {
        let context = ConnectionContext(connection: Connection(unavailable: .bluetooth), role: .server, state: .ready)
        let now = Date()
        context.lastInboundAt = now.addingTimeInterval(-31)
        XCTAssertTrue(context.shouldCheckHeartbeat(now: now, interval: 30))
        context.lastPingAt = now
        XCTAssertFalse(context.shouldCheckHeartbeat(now: now.addingTimeInterval(1), interval: 30))
        XCTAssertTrue(context.shouldCheckHeartbeat(now: now.addingTimeInterval(31), interval: 30))
        context.lastInboundAt = now.addingTimeInterval(32)
        XCTAssertFalse(context.shouldCheckHeartbeat(now: now.addingTimeInterval(40), interval: 30))
    }

    private func pair() -> (StreamTransport, StreamTransport) {
        func streams() -> (InputStream, OutputStream) {
            var read: Unmanaged<CFReadStream>?
            var write: Unmanaged<CFWriteStream>?
            CFStreamCreateBoundPair(nil, &read, &write, 257)
            return (read!.takeRetainedValue(), write!.takeRetainedValue())
        }
        let (aIn, bOut) = streams()
        let (bIn, aOut) = streams()
        return (StreamTransport(input: aIn, output: aOut, owner: NSObject(), name: "a"),
                StreamTransport(input: bIn, output: bOut, owner: NSObject(), name: "b"))
    }

    func testPartialWritesPreserveConcurrentFrameBoundaries() async throws {
        let (a, b) = pair()
        let sender = Connection(bluetooth: { a })
        let receiver = Connection(bluetooth: { b })
        let ready = expectation(description: "streams opened")
        ready.expectedFulfillmentCount = 2
        let received = expectation(description: "all framed payloads intact")
        received.expectedFulfillmentCount = 3
        await receiver.start(onReady: { ready.fulfill() }, onMessage: { type, body in
            XCTAssertEqual(body, Data(repeating: type, count: 70_000))
            received.fulfill()
        }, onClose: { _ in })
        await sender.start(onReady: { ready.fulfill() }, onMessage: { _, _ in }, onClose: { _ in })
        await fulfillment(of: [ready], timeout: 3)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for type: UInt8 in [0x10, 0x11, 0x30] {
                group.addTask { try await sender.send(type: type, body: Data(repeating: type, count: 70_000)) }
            }
            try await group.waitForAll()
        }
        await fulfillment(of: [received], timeout: 5)
        await sender.close()
        await receiver.close()
    }

    func testCloseReleasesBlockedWriterAndReader() async throws {
        let (a, b) = pair()
        async let startA: Void = a.start()
        async let startB: Void = b.start()
        _ = try await (startA, startB)
        let writer = Task { try await a.send(Data(repeating: 1, count: 500_000)) }
        let reader = Task { try await a.receive() }
        await Task.yield()
        a.close()
        do { try await writer.value; XCTFail("closed writer must fail") } catch { }
        let data = try await reader.value
        XCTAssertNil(data)
        b.close()
    }
}
