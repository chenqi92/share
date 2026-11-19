import Foundation

/// Joins background WatchConnectivity files with the optional command from older watches.
/// A dispatched directory is also the stable source used by transfer history.
public final class WatchFileOutbox: @unchecked Sendable {
    public struct Delivery {
        public let peerID: String
        public let url: URL
    }

    private struct Intent: Codable {
        var peerID: String?
        var fingerprint: String?
        var name: String?
    }

    private let root: URL
    private let lock = NSLock()
    private let fm = FileManager.default

    public init(root: URL) { self.root = root }

    public func record(ref: String, peerID: String?, name: String?, fingerprint: String? = nil, file: URL? = nil) throws {
        guard !ref.isEmpty, ref.utf8.count <= 128, ref.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { throw CocoaError(.fileReadInvalidFileName) }
        try lock.withLock {
            let sent = root.appendingPathComponent("forwarded/\(ref)")
            if fm.fileExists(atPath: sent.path) {
                let ticket = try JSONDecoder().decode(Intent.self, from: Data(contentsOf: sent.appendingPathComponent("intent.json")))
                if let peerID, ticket.peerID != peerID { throw CocoaError(.fileReadCorruptFile) }
                if let fingerprint, ticket.fingerprint != fingerprint { throw CocoaError(.fileReadCorruptFile) }
                return
            }
            let dir = root.appendingPathComponent("pending/\(ref)")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let meta = dir.appendingPathComponent("intent.json")
            var intent = fm.fileExists(atPath: meta.path)
                ? try JSONDecoder().decode(Intent.self, from: Data(contentsOf: meta))
                : Intent()
            if let peerID {
                guard !peerID.isEmpty, intent.peerID == nil || intent.peerID == peerID else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                intent.peerID = peerID
            }
            if let fingerprint {
                guard fingerprint.utf8.count == 32, fingerprint.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                      intent.fingerprint == nil || intent.fingerprint == fingerprint else { throw CocoaError(.fileReadCorruptFile) }
                intent.fingerprint = fingerprint
            }
            if intent.name == nil, let name, !name.isEmpty {
                intent.name = ShareEngine.sanitizedPathComponent(name)
            }
            try JSONEncoder().encode(intent).write(to: meta, options: .atomic)
            let bytes = dir.appendingPathComponent("bytes")
            if !fm.fileExists(atPath: bytes.path) {
                let source = file ?? root.appendingPathComponent(ref)
                if let attrs = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                   attrs.isRegularFile == true, attrs.isSymbolicLink != true {
                    try fm.moveItem(at: source, to: bytes)
                } else if file != nil {
                    throw CocoaError(.fileReadUnknown)
                }
            }
        }
    }

    public func forward(available: [String: String], send: (Delivery) -> Void, onError: (Error) -> Void) {
        guard !available.isEmpty else { return }
        let pending = root.appendingPathComponent("pending")
        guard let dirs = try? fm.contentsOfDirectory(at: pending, includingPropertiesForKeys: nil) else { return }
        for dir in dirs {
            do {
                let delivery = try lock.withLock { () -> Delivery? in
                    let ticket = dir.appendingPathComponent("intent.json")
                    guard fm.fileExists(atPath: ticket.path) else { return nil }
                    let intent = try JSONDecoder().decode(Intent.self, from: Data(contentsOf: ticket))
                    guard let peer = intent.peerID, let discovered = available[peer],
                          intent.fingerprint == nil || intent.fingerprint == discovered else { return nil }
                    let name = intent.name ?? dir.lastPathComponent
                    let bytes = dir.appendingPathComponent("bytes")
                    let content = dir.appendingPathComponent("file")
                    let named = content.appendingPathComponent(name)
                    if !fm.fileExists(atPath: named.path) {
                        guard fm.fileExists(atPath: bytes.path) else { return nil }
                        try fm.createDirectory(at: content, withIntermediateDirectories: true)
                        try fm.moveItem(at: bytes, to: named)
                    }
                    let forwarded = root.appendingPathComponent("forwarded")
                    try fm.createDirectory(at: forwarded, withIntermediateDirectories: true)
                    let destination = forwarded.appendingPathComponent(dir.lastPathComponent)
                    try fm.moveItem(at: dir, to: destination)
                    return Delivery(peerID: peer, url: destination.appendingPathComponent("file").appendingPathComponent(name))
                }
                if let delivery { send(delivery) }
            } catch { onError(error) }
        }
    }
}
