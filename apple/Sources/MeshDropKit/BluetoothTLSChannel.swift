import Foundation
import Network

/// Network.framework terminates TLS; CoreBluetooth only sees TLS records. A private
/// Unix socket connects the two APIs without opening an IP port or requiring Wi-Fi.
@MainActor
final class BluetoothTLSChannel {
    enum Role {
        case client(expectedFingerprint: String)
        case server

        var expectedFingerprint: String? {
            if case let .client(fingerprint) = self { return fingerprint }
            return nil
        }
    }

    private let stream: StreamTransport
    private let role: Role
    private let directory: URL
    private let endpoint: NWEndpoint
    private let listener: NWListener
    private let dialParameters: NWParameters
    private var relay: NWConnection?
    private var dial: NWConnection?
    private var accepted = false
    private var closed = false

    init(stream: StreamTransport, identity: Identity, role: Role) throws {
        self.stream = stream
        self.role = role
        let tls = try TransportSecurity.parameters(identity: identity, expectedFingerprint: role.expectedFingerprint)
        let listenParameters: NWParameters
        switch role {
        case .server:
            listenParameters = tls
            dialParameters = .tcp
        case .client:
            listenParameters = .tcp
            dialParameters = tls
        }

        // mkdtemp grants 0700 before the listener is bound.
        let parent = FileManager.default.temporaryDirectory
        var template = Array(parent.appendingPathComponent("mdXXXXXX").path.utf8CString)
        guard mkdtemp(&template) != nil else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        directory = URL(fileURLWithPath: String(cString: template), isDirectory: true)
        do {
            var path = directory.appendingPathComponent("s").path
            if path.utf8.count >= MemoryLayout.size(ofValue: sockaddr_un().sun_path) {
                // macOS and Simulator container paths can exceed sockaddr_un.
                // volfs addresses the same private directory by device and inode.
                var info = stat()
                guard stat(directory.path, &info) == 0 else { throw POSIXError(.ENOENT) }
                let short = "/.vol/\(info.st_dev)/\(info.st_ino)"
                var resolved = stat()
                guard stat(short, &resolved) == 0, resolved.st_dev == info.st_dev, resolved.st_ino == info.st_ino else {
                    throw POSIXError(.ENAMETOOLONG)
                }
                path = short + "/s"
            }
            endpoint = .unix(path: path)
            listenParameters.requiredLocalEndpoint = endpoint
            listener = try NWListener(using: listenParameters)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func start(onTLS: @escaping @Sendable (NWConnection) -> Void,
               onFailure: @escaping @Sendable (Error) -> Void) {
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated {
                guard let self, !self.closed, !self.accepted else {
                    connection.cancel()
                    return
                }
                self.accepted = true
                self.listener.cancel()
                switch self.role {
                case .server: onTLS(connection)
                case .client: self.pump(connection, onFailure: onFailure)
                }
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                switch state {
                case .ready:
                    let connection = NWConnection(to: self.endpoint, using: self.dialParameters)
                    self.dial = connection
                    switch self.role {
                    case .server: self.pump(connection, onFailure: onFailure)
                    case .client: onTLS(connection)
                    }
                case .failed(let error): onFailure(error)
                default: break
                }
            }
        }
        listener.start(queue: .main)
    }

    private func pump(_ connection: NWConnection, onFailure: @escaping @Sendable (Error) -> Void) {
        relay = connection
        connection.stateUpdateHandler = { if case let .failed(error) = $0 { onFailure(error) } }
        connection.start(queue: .main)
        Task {
            do {
                while let bytes = try await stream.receive() {
                    try await connection.writeChunk(bytes)
                }
                try await connection.writeChunk(nil)
            } catch { if !closed { onFailure(error) } }
        }
        Task {
            do {
                while let bytes = try await connection.readChunk() {
                    try await stream.send(bytes)
                }
                stream.close()
            } catch { if !closed { onFailure(error) } }
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        listener.cancel()
        dial?.cancel()
        relay?.cancel()
        stream.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
