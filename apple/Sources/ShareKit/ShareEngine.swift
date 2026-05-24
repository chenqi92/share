import Foundation
import Network
import Combine
import OSLog

private let log = Logger(subsystem: "drop.mesh.MeshDropKit", category: "Engine")

/// 顶层引擎：单例。持有 [Identity]、[Discovery]、[TrustStore]，对外暴露设备列表、
/// 收件箱、待审配对请求。
///
/// 业务流程一览：
/// - **发送**：UI 调用 `sendText(to:content:)` → 建出方 [Connection] → 收到 HELLO_ACK
///   后立即 send TEXT → 关连接。
/// - **接收**：[Discovery] 的 listener 把入站 NWConnection 交给本引擎；本引擎
///   做握手，未信任则把 [PairingRequest] 投到 [pendingPairings]；批准 / 信任后
///   回 HELLO_ACK 进入 .ready；后续收到 TEXT 即加入 [inbox]。
@MainActor
public final class ShareEngine: ObservableObject {
    public static let shared = ShareEngine()

    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var inbox: [InboxItem] = []
    @Published public private(set) var pendingPairings: [PairingRequest] = []
    @Published public private(set) var trusted: [TrustRecord] = []
    @Published public private(set) var identity: Identity
    @Published public var displayName: String

    private var discovery: Discovery?
    private let trustStore = TrustStore()
    private var devicesTask: Task<Void, Never>?
    private var contexts: [UUID: ConnectionContext] = [:]

    private init() {
        self.identity = IdentityStore.loadOrCreate()
        self.displayName = Self.defaultDisplayName()
    }

    public func start() {
        guard discovery == nil else { return }
        do {
            let d = try Discovery(
                identity: identity,
                displayName: displayName,
                model: Self.systemModel()
            )

            // 入站连接交给本引擎处理
            d.onIncomingConnection = { [weak self] nwConn in
                guard let self else { nwConn.cancel(); return }
                Task { @MainActor in
                    await self.acceptIncoming(nwConn)
                }
            }

            try d.start()
            discovery = d

            devicesTask = Task { [weak self] in
                guard let self else { return }
                for await list in d.devices {
                    await MainActor.run { self.devices = list }
                }
            }

            Task { await refreshTrusted() }
        } catch {
            log.error("ShareEngine start failed: \(error.localizedDescription)")
        }
    }

    public func stop() {
        discovery?.stop()
        discovery = nil
        devicesTask?.cancel()
        devicesTask = nil
        devices = []

        let activeContexts = Array(contexts.values)
        contexts.removeAll()
        Task {
            for ctx in activeContexts { await ctx.connection.close() }
        }
    }

    // MARK: - 出方：发送

    public func sendText(to device: Device, content: String) {
        let conn = Connection(connectingTo: device)
        let ctxID = UUID()
        let ctx = ConnectionContext(
            id: ctxID,
            connection: conn,
            role: .client(target: device, pendingText: content),
            state: .awaitingHelloAck
        )
        contexts[ctxID] = ctx

        Task {
            await conn.start(
                onReady: { [weak self] in
                    await self?.sendInitialHello(contextID: ctxID)
                },
                onMessage: { [weak self] type, body in
                    await self?.handleMessage(type: type, body: body, contextID: ctxID)
                },
                onClose: { [weak self] err in
                    await self?.closeContext(id: ctxID, error: err)
                }
            )
        }
    }

    // MARK: - 配对决定

    public func respondToPairing(_ requestID: UUID, decision: PairingDecision) {
        guard let req = pendingPairings.first(where: { $0.id == requestID }) else { return }
        pendingPairings.removeAll { $0.id == requestID }

        let entry = contexts.first { _, c in
            if case .awaitingPairApproval(let r) = c.state, r.id == requestID { return true }
            return false
        }
        guard let (ctxID, ctx) = entry else { return }

        Task {
            switch decision {
            case .reject:
                await closeContext(id: ctxID, error: nil)
            case .allowOnce:
                await sendAckAndReady(contextID: ctxID, peer: req.peer)
            case .trust:
                await trustStore.trust(fingerprint: req.peer.fingerprint, name: req.peer.name)
                await refreshTrusted()
                await sendAckAndReady(contextID: ctxID, peer: req.peer)
            }
            _ = ctx  // 沉默 unused
        }
    }

    public func revokeTrust(fingerprint: String) {
        Task {
            await trustStore.revoke(fingerprint)
            await refreshTrusted()
        }
    }

    public func clearInbox() {
        inbox.removeAll()
    }

    // MARK: - 入站：accept 与握手

    private func acceptIncoming(_ nwConn: NWConnection) async {
        let conn = Connection(nwConnection: nwConn)
        let ctxID = UUID()
        let ctx = ConnectionContext(
            id: ctxID,
            connection: conn,
            role: .server,
            state: .awaitingHello
        )
        contexts[ctxID] = ctx

        await conn.start(
            onReady: { },
            onMessage: { [weak self] type, body in
                await self?.handleMessage(type: type, body: body, contextID: ctxID)
            },
            onClose: { [weak self] err in
                await self?.closeContext(id: ctxID, error: err)
            }
        )
    }

    // MARK: - 消息路由

    private func handleMessage(type: UInt8, body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }

        switch (ctx.state, type) {
        case (.awaitingHello, MessageType.hello):
            await serverReceivedHello(body: body, contextID: contextID)

        case (.awaitingHelloAck, MessageType.helloAck):
            await clientReceivedAck(body: body, contextID: contextID)

        case (.ready, MessageType.text):
            await handleReceivedText(body: body, contextID: contextID)

        case (.ready, MessageType.ping):
            try? await ctx.connection.send(type: MessageType.pong, body: Data("{}".utf8))

        case (.ready, MessageType.pong):
            break

        default:
            log.info("dropping unexpected message type=\(type) in state=\(String(describing: ctx.state))")
            await closeContext(id: contextID, error: nil)
        }
    }

    private func sendInitialHello(contextID: UUID) async {
        guard contexts[contextID] != nil else { return }
        let hello = HelloMessage(
            id: identity.id,
            name: displayName,
            os: .current,
            model: Self.systemModel(),
            fp: identity.fingerprint,
            protocol_versions: [1]
        )
        do {
            let body = try MessageCodec.encode(hello)
            try await contexts[contextID]?.connection.send(type: MessageType.hello, body: body)
        } catch {
            await closeContext(id: contextID, error: error)
        }
    }

    private func serverReceivedHello(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }

        guard let hello = try? MessageCodec.decode(HelloMessage.self, from: body) else {
            await closeContext(id: contextID, error: nil); return
        }
        let supported: Set<UInt8> = [1]
        guard supported.intersection(hello.protocol_versions).max() != nil else {
            log.info("no protocol version intersection; closing")
            await closeContext(id: contextID, error: nil); return
        }

        let peer = Device(
            id: hello.id,
            name: hello.name,
            os: hello.os,
            model: hello.model,
            fingerprint: hello.fp,
            port: 0,
            protocolVersion: 1
        )
        ctx.peer = peer

        if await trustStore.isTrusted(hello.fp) {
            await trustStore.touch(fingerprint: hello.fp)
            await refreshTrusted()
            await sendAckAndReady(contextID: contextID, peer: peer)
        } else {
            let req = PairingRequest(peer: peer)
            ctx.state = .awaitingPairApproval(req)
            pendingPairings.append(req)
        }
    }

    private func sendAckAndReady(contextID: UUID, peer: Device) async {
        guard let ctx = contexts[contextID] else { return }

        let ack = HelloAckMessage(
            id: identity.id,
            name: displayName,
            os: .current,
            model: Self.systemModel(),
            fp: identity.fingerprint,
            protocol_versions: [1],
            selected_version: 1
        )
        do {
            let body = try MessageCodec.encode(ack)
            try await ctx.connection.send(type: MessageType.helloAck, body: body)
            ctx.state = .ready
            ctx.peer = peer
        } catch {
            await closeContext(id: contextID, error: error)
        }
    }

    private func clientReceivedAck(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }
        guard let ack = try? MessageCodec.decode(HelloAckMessage.self, from: body) else {
            await closeContext(id: contextID, error: nil); return
        }
        guard case .client(let target, let pendingText) = ctx.role else {
            await closeContext(id: contextID, error: nil); return
        }
        // 服务端公告的 fp 必须等于 mDNS TXT 中声明的 fp（防 mDNS 伪造）
        guard ack.fp == target.fingerprint else {
            log.info("server fp mismatch; closing")
            await closeContext(id: contextID, error: nil); return
        }

        ctx.state = .ready
        ctx.peer = target

        let msg = TextMessage(
            id: UUID().uuidString.lowercased(),
            content: pendingText,
            ts: Int64(Date().timeIntervalSince1970)
        )
        do {
            let textBody = try MessageCodec.encode(msg)
            try await ctx.connection.send(type: MessageType.text, body: textBody)
            // 等对端读完缓冲再断；NWConnection 没有 half-close API，简单延迟一下
            try? await Task.sleep(nanoseconds: 200_000_000)
            await ctx.connection.close()
        } catch {
            await closeContext(id: contextID, error: error)
        }
    }

    private func handleReceivedText(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let text = try? MessageCodec.decode(TextMessage.self, from: body) else { return }
        let item = InboxItem(peer: peer, kind: .text(text.content), receivedAt: Date())
        inbox.insert(item, at: 0)
    }

    private func closeContext(id: UUID, error: Error?) async {
        guard let ctx = contexts.removeValue(forKey: id) else { return }
        if case .awaitingPairApproval(let req) = ctx.state {
            pendingPairings.removeAll { $0.id == req.id }
        }
        ctx.state = .closed
        await ctx.connection.close()
        if let error {
            log.debug("context \(id) closed with error: \(error.localizedDescription)")
        }
    }

    private func refreshTrusted() async {
        let snap = await trustStore.snapshot()
        await MainActor.run { self.trusted = snap }
    }

    // MARK: - 平台默认信息

    private static func defaultDisplayName() -> String {
        #if os(iOS)
        return UIDeviceWrapper.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }

    private static func systemModel() -> String? {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        return String(cString: buf)
        #elseif os(iOS)
        var sys = utsname()
        uname(&sys)
        return withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        #else
        return nil
        #endif
    }
}

#if os(iOS)
import UIKit
private enum UIDeviceWrapper {
    static var name: String { UIDevice.current.name }
}
#endif

// MARK: - ConnectionContext

@MainActor
final class ConnectionContext {
    enum Role {
        case server
        case client(target: Device, pendingText: String)
    }

    enum State {
        case awaitingHello                   // server：等对方 HELLO
        case awaitingPairApproval(PairingRequest)
        case awaitingHelloAck                // client：已发 HELLO，等 ack
        case ready
        case closed
    }

    let id: UUID
    let connection: Connection
    let role: Role
    var state: State
    var peer: Device?

    init(id: UUID, connection: Connection, role: Role, state: State) {
        self.id = id
        self.connection = connection
        self.role = role
        self.state = state
    }
}
