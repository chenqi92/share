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
        let client = Identity(id: "client", privateKey: .init())
        let server = Identity(id: "server", privateKey: .init())
        let sender = Connection(bluetooth: { a }, identity: client, role: .client(expectedFingerprint: server.fingerprint))
        let receiver = Connection(bluetooth: { b }, identity: server, role: .server)
        let ready = expectation(description: "streams opened")
        ready.expectedFulfillmentCount = 2
        let received = expectation(description: "all framed payloads intact")
        received.expectedFulfillmentCount = 3
        let echoed = expectation(description: "return frame decrypted on client")
        echoed.expectedFulfillmentCount = 3
        await receiver.start(onReady: {
            let fp = await receiver.authenticatedFingerprint
            XCTAssertEqual(fp, client.fingerprint)
            ready.fulfill()
        }, onMessage: { type, body in
            guard type != MessageType.ping && type != MessageType.pong else { return }
            XCTAssertEqual(body, Data(repeating: type, count: 70_000))
            received.fulfill()
            do { try await receiver.send(type: type, body: body) }
            catch { XCTFail("Return send failed: \(error)") }
        }, onClose: { _ in })
        await sender.start(onReady: {
            let fp = await sender.authenticatedFingerprint
            XCTAssertEqual(fp, server.fingerprint)
            ready.fulfill()
        }, onMessage: { type, body in
            guard type != MessageType.ping && type != MessageType.pong else { return }
            XCTAssertEqual(body, Data(repeating: type, count: 70_000))
            echoed.fulfill()
        }, onClose: { _ in })
        await fulfillment(of: [ready], timeout: 5)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for type: UInt8 in [0x10, 0x11, 0x30] {
                group.addTask { try await sender.send(type: type, body: Data(repeating: type, count: 70_000)) }
            }
            try await group.waitForAll()
        }
        await fulfillment(of: [received, echoed], timeout: 8)
        await sender.close()
        await receiver.close()
    }

    func testClosingAfterSendFlushesLastBluetoothFrame() async throws {
        let (a, b) = pair()
        let server = Identity(id: "server", privateKey: .init())
        let client = Identity(id: "client", privateKey: .init())
        let sender = Connection(bluetooth: { a }, identity: client, role: .client(expectedFingerprint: server.fingerprint))
        let receiver = Connection(bluetooth: { b }, identity: server, role: .server)
        let ready = expectation(description: "TLS connections ready")
        ready.expectedFulfillmentCount = 2
        let received = expectation(description: "final frame reached the receiver")
        let payload = Data(repeating: 42, count: 350_000)
        let closed = expectation(description: "flushed channel closed")
        await receiver.start(onReady: { ready.fulfill() }, onMessage: { type, bytes in
            guard type == MessageType.text else { return }
            XCTAssertEqual(bytes, payload)
            received.fulfill()
        }, onClose: { _ in closed.fulfill() })
        await sender.start(onReady: { ready.fulfill() }, onMessage: { _, _ in }, onClose: { _ in })
        await fulfillment(of: [ready], timeout: 5)
        try await sender.send(type: MessageType.text, body: payload)
        await sender.close()
        await fulfillment(of: [received, closed], timeout: 5)
        await receiver.close()
    }

    func testBluetoothRejectsWrongIdentityBeforeApplicationFrames() async {
        let (a, b) = pair()
        let client = Identity(id: "client", privateKey: .init())
        let server = Identity(id: "server", privateKey: .init())
        let sender = Connection(bluetooth: { a }, identity: client, role: .client(expectedFingerprint: client.fingerprint))
        let receiver = Connection(bluetooth: { b }, identity: server, role: .server)
        let rejected = expectation(description: "fingerprint mismatch")
        await receiver.start(onReady: {}, onMessage: { _, _ in XCTFail("Unexpected frame") }, onClose: { _ in })
        await sender.start(onReady: { XCTFail("Accepted wrong fingerprint") }, onMessage: { _, _ in
            XCTFail("Unexpected frame")
        }, onClose: { error in
            XCTAssertNotNil(error)
            rejected.fulfill()
        })
        await fulfillment(of: [rejected], timeout: 5)
        await sender.close()
        await receiver.close()
    }

    func testCloseReleasesBlockedWriterAndReader() async throws {
        let (a, b) = pair()
        async let startA: Void = a.start()
        async let startB: Void = b.start()
        _ = try await (startA, startB)
        try await a.send(Data())
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
