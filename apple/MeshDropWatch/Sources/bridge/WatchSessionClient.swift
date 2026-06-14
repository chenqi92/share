import Foundation
import OSLog
import WatchConnectivity

/// WatchConnectivity 客户端：activate / 命令请求-回执 / 反向事件分发 / 文件转移。
///
/// 设计原则：
/// - 网络层职责单一，不包含任何 UI / @Published 状态（那是 [WatchEngineProxy] 的事）。
/// - 命令请求走 `sendMessage(_:replyHandler:errorHandler:)`，回执从 reply 解析。
/// - 反向事件走 `session(_:didReceiveMessage:)`，通过 `onEvent` 回调上抛。
/// - 大文件用 `transferFile(_:metadata:)`，metadata 里挂 `peerId` + 命令 id。
/// - 离线 / iPhone 不可达时缓冲事件 / 状态由 proxy 决定如何降级。
final class WatchSessionClient: NSObject {

    enum BridgeError: LocalizedError {
        case sessionUnsupported
        case sessionUnreachable
        case timeout
        case underlying(Error)
        case malformedAck(String)

        var errorDescription: String? {
            switch self {
            case .sessionUnsupported:   return L10n.errorBridgeUnsupported
            case .sessionUnreachable:   return L10n.errorBridgeUnreachable
            case .timeout:              return L10n.errorCommandTimeout
            case .underlying(let e):    return e.localizedDescription
            case .malformedAck(let s):  return L10n.errorMalformedAck(s)
            }
        }
    }

    static let commandTimeoutSeconds: Double = 10.0

    /// 桥接通道是否可达（companion 在身边）。WCSession.isReachable 镜像。
    private(set) var isReachable: Bool = false {
        didSet { if oldValue != isReachable { onReachabilityChanged?(isReachable) } }
    }

    /// 上次激活错误（如有）。
    private(set) var lastActivationError: String?

    // MARK: - 回调（proxy 注册）

    var onReachabilityChanged: ((Bool) -> Void)?
    var onEvent: ((BridgeEvent) -> Void)?
    var onActivationCompleted: ((Bool, String?) -> Void)?
    /// iPhone 经 transferFile 中转来的入站文件落盘完成：(ref, 本地副本 URL)。
    var onFileReceived: ((String, URL) -> Void)?

    // MARK: - 内部

    private let log = Logger(subsystem: "com.welape.meshdrop", category: "WatchBridge")
    private var session: WCSession?

    func start() {
        guard WCSession.isSupported() else {
            log.error("WCSession 不被支持")
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        session = s
    }

    // MARK: - 命令请求

    /// 发命令，等回执。10s 超时。
    func sendCommand(_ command: BridgeCommand) async throws -> BridgeAck {
        guard let session, session.activationState == .activated else {
            throw BridgeError.sessionUnsupported
        }
        guard session.isReachable else {
            throw BridgeError.sessionUnreachable
        }
        let dict = try BridgeCodec.dict(from: command)
        return try await withThrowingTaskGroup(of: BridgeAck.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<BridgeAck, Error>) in
                    session.sendMessage(dict, replyHandler: { reply in
                        do {
                            let ack = try BridgeCodec.decode(BridgeAck.self, from: reply)
                            cont.resume(returning: ack)
                        } catch {
                            cont.resume(throwing: BridgeError.malformedAck(error.localizedDescription))
                        }
                    }, errorHandler: { err in
                        cont.resume(throwing: BridgeError.underlying(err))
                    })
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(Self.commandTimeoutSeconds * 1_000_000_000))
                throw BridgeError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// 传文件：metadata 里放 `ref`（裸 token）+ peerId + name。
    /// iPhone 端 didReceive 按 `ref` 落盘到 Caches/com.welape.meshdrop.watchbridge/<ref>，
    /// 待随后到达的 `send_file_ref` 命令（payload.fileRef 同 ref）凭 ref 取文件 + peerId 交 ShareEngine。
    /// 见 companion-bridges.md §4.1。返回本次 transfer 用的 ref，供调用方发命令时复用。
    @discardableResult
    func transferFile(at url: URL, peerId: String, name: String) throws -> String {
        guard let session, session.activationState == .activated else {
            throw BridgeError.sessionUnsupported
        }
        let ref = "ref-" + UUID().uuidString.lowercased()
        let metadata: [String: Any] = [
            "v": BridgeProtocol.version,
            "ref": ref,
            "type": BridgeCommandType.sendFileRef.rawValue,
            "peerId": peerId,
            "name": name,
        ]
        session.transferFile(url, metadata: metadata)
        return ref
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionClient: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            log.error("activation 失败：\(error.localizedDescription)")
            lastActivationError = error.localizedDescription
        } else {
            lastActivationError = nil
        }
        isReachable = session.isReachable
        onActivationCompleted?(activationState == .activated, lastActivationError)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
    }

    /// iPhone 端推送的事件（不带 replyHandler）。
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        dispatchIncoming(message)
    }

    /// 兼容带 replyHandler 的（即使 iPhone 端走双向，handler 也得回个 ack）。
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        dispatchIncoming(message)
        replyHandler([:])
    }

    private func dispatchIncoming(_ message: [String: Any]) {
        do {
            let event = try BridgeCodec.decode(BridgeEvent.self, from: message)
            onEvent?(event)
        } catch {
            log.error("收到非事件 message：\(error.localizedDescription)")
        }
    }

    /// iPhone transferFile 中转来的入站文件。WCSession 会在 inbox 临时目录给一个 fileURL，
    /// 必须在本回调返回前把它移走（系统随后清理）。落到 caches 下按 ref 命名。
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let ref = (file.metadata?["ref"] as? String) ?? UUID().uuidString
        let name = (file.metadata?["name"] as? String) ?? ref
        let dst = Self.inboxFileURL(ref: ref, name: name)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.moveItem(at: file.fileURL, to: dst)
            log.info("收到入站文件 ref=\(ref, privacy: .public)")
            onFileReceived?(ref, dst)
        } catch {
            log.error("入站文件落盘失败：\(error.localizedDescription)")
        }
    }

    /// 入站文件本地落盘约定路径（caches/com.welape.meshdrop.inbox/<ref>-<name>）。
    static func inboxFileURL(ref: String, name: String) -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .cachesDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("com.welape.meshdrop.inbox", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(ref)-\(name)")
    }
}
