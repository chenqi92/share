import Foundation

/// L2CAP exposes ordered byte streams. Keep partial writes and backpressure here so
/// concurrent protocol frames cannot interleave when the Bluetooth buffer fills.
@MainActor
final class StreamTransport: NSObject, StreamDelegate {
    let name: String
    private let input: InputStream
    private let output: OutputStream
    private let owner: AnyObject
    private var opening: CheckedContinuation<Void, Error>?
    private var reader: CheckedContinuation<Data?, Error>?
    private struct Write {
        let data: Data
        var offset = 0
        let completion: CheckedContinuation<Void, Error>
    }
    private var writes: [Write] = []
    private var opened = Set<ObjectIdentifier>()
    private var terminalError: Error?
    private var closed = false

    init(input: InputStream, output: OutputStream, owner: AnyObject, name: String) {
        self.input = input
        self.output = output
        self.owner = owner
        self.name = name
    }

    func start() async throws {
        guard !closed else { throw terminalError ?? ConnectionError.alreadyClosed }
        try await withCheckedThrowingContinuation { continuation in
            opening = continuation
            for stream in [input as Stream, output as Stream] {
                stream.delegate = self
                stream.schedule(in: .main, forMode: .common)
                stream.open()
            }
        }
    }

    func receive() async throws -> Data? {
        if closed {
            if let terminalError { throw terminalError }
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            reader = continuation
            readAvailable()
        }
    }

    func send(_ data: Data) async throws {
        guard !closed else { throw terminalError ?? ConnectionError.alreadyClosed }
        guard writes.reduce(0, { $0 + $1.data.count - $1.offset }) + data.count <= Frame.maxLength * 2 else {
            throw ConnectionError.bufferFull
        }
        try await withCheckedThrowingContinuation { continuation in
            writes.append(Write(data: data, completion: continuation))
            writeAvailable()
        }
    }

    func close(error: Error? = nil) {
        guard !closed else { return }
        closed = true
        terminalError = error
        for stream in [input as Stream, output as Stream] {
            stream.delegate = nil
            stream.close()
            stream.remove(from: .main, forMode: .common)
        }
        opening?.resume(throwing: error ?? ConnectionError.alreadyClosed)
        opening = nil
        if let error { reader?.resume(throwing: error) }
        else { reader?.resume(returning: nil) }
        reader = nil
        let pending = writes
        writes.removeAll()
        for write in pending { write.completion.resume(throwing: error ?? ConnectionError.alreadyClosed) }
    }

    nonisolated func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        MainActor.assumeIsolated { handle(aStream, event: eventCode) }
    }

    private func handle(_ stream: Stream, event: Stream.Event) {
        guard !closed else { return }
        switch event {
        case .openCompleted:
            opened.insert(ObjectIdentifier(stream))
            if opened.count == 2 {
                opening?.resume()
                opening = nil
            }
        case .hasBytesAvailable: readAvailable()
        case .hasSpaceAvailable: writeAvailable()
        case .errorOccurred: close(error: stream.streamError ?? ConnectionError.alreadyClosed)
        case .endEncountered: close()
        default: break
        }
    }

    private func readAvailable() {
        guard let reader, input.hasBytesAvailable, !closed else { return }
        var bytes = [UInt8](repeating: 0, count: 32 * 1024)
        let count = input.read(&bytes, maxLength: bytes.count)
        if count < 0 { close(error: input.streamError ?? ConnectionError.alreadyClosed); return }
        if count == 0 { return }
        self.reader = nil
        reader.resume(returning: Data(bytes.prefix(count)))
    }

    private func writeAvailable() {
        while !writes.isEmpty, output.hasSpaceAvailable, !closed {
            let data = writes[0].data
            let offset = writes[0].offset
            let count = data.withUnsafeBytes { bytes in
                output.write(bytes.bindMemory(to: UInt8.self).baseAddress!.advanced(by: offset),
                             maxLength: min(data.count - offset, 32 * 1024))
            }
            if count < 0 { close(error: output.streamError ?? ConnectionError.alreadyClosed); return }
            if count == 0 { return }
            writes[0].offset += count
            if writes[0].offset == data.count { writes.removeFirst().completion.resume() }
        }
    }
}
