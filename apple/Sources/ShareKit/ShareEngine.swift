import Foundation
import Network
import Combine
import CryptoKit
import OSLog

private let log = Logger(subsystem: "drop.mesh.MeshDropKit", category: "Engine")

/// 顶层引擎：单例。持有 [Identity]、[Discovery]、[TrustStore]，对外暴露设备列表、
/// 发送/接收历史、待审配对请求、待审文件 offer。
///
/// 完整链路：
/// - 文本发送：UI → `sendText(to:content:)` → 出方 [Connection] → HELLO/ACK → TEXT → 关
/// - 文件发送：UI → `sendFile(to:url:)` → 出方 [Connection] → HELLO/ACK → FILE_OFFER →
///   FILE_ACCEPT → 流式 FILE_CHUNK → FILE_COMPLETE → 关
/// - 接收：listener accept → HELLO → ACK → 收到 TEXT 直接入 history；收到 FILE_OFFER
///   投递 [PendingFileOffer]，用户接受后 send FILE_ACCEPT 进入接收，chunk 累积写盘，
///   收齐校验 sha256 后 send FILE_COMPLETE。
@MainActor
public final class ShareEngine: ObservableObject {
    public static let shared = ShareEngine()

    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var history: [HistoryItem] = []
    @Published public private(set) var pendingPairings: [PairingRequest] = []
    @Published public private(set) var pendingFileOffers: [PendingFileOffer] = []
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

    // MARK: - 生命周期

    public func start() {
        guard discovery == nil else { return }
        do {
            let d = try Discovery(
                identity: identity,
                displayName: displayName,
                model: Self.systemModel()
            )
            d.onIncomingConnection = { [weak self] nwConn in
                guard let self else { nwConn.cancel(); return }
                Task { @MainActor in await self.acceptIncoming(nwConn) }
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
        let active = Array(contexts.values)
        contexts.removeAll()
        Task { for ctx in active { await ctx.connection.close() } }
    }

    // MARK: - 历史管理

    public func removeHistoryItem(_ id: UUID) {
        history.removeAll { $0.id == id }
    }

    public func clearHistory() {
        history.removeAll()
    }

    // MARK: - 发送文本

    public func sendText(to device: Device, content: String) {
        let historyItem = HistoryItem(
            peer: device,
            direction: .outgoing,
            kind: .text(content),
            status: .pending
        )
        history.insert(historyItem, at: 0)

        let conn = Connection(connectingTo: device)
        let ctx = ConnectionContext(
            connection: conn,
            role: .client(target: device, payload: .text(content)),
            state: .awaitingHelloAck
        )
        ctx.historyID = historyItem.id
        contexts[ctx.id] = ctx
        startConnection(ctx)
    }

    // MARK: - 发送文件

    public func sendFile(to device: Device, sourceURL: URL) {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let fileSize = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
            let fileName = sourceURL.lastPathComponent

            // 占位历史项（先 pending，之后计算 sha256）
            let historyItem = HistoryItem(
                peer: device,
                direction: .outgoing,
                kind: .file(name: fileName, size: fileSize, url: sourceURL),
                status: .pending
            )
            history.insert(historyItem, at: 0)
            let historyID = historyItem.id

            // 后台算 sha256（大文件流式），算完后启动连接
            Task.detached(priority: .userInitiated) { [weak self] in
                let hash: String
                do {
                    hash = try Self.sha256OfFile(at: sourceURL)
                } catch {
                    if needsAccess { sourceURL.stopAccessingSecurityScopedResource() }
                    await MainActor.run {
                        self?.updateHistoryStatus(historyID, status: .failed("无法读取文件: \(error.localizedDescription)"))
                    }
                    return
                }
                await MainActor.run {
                    self?.startFileSend(
                        to: device,
                        historyID: historyID,
                        sourceURL: sourceURL,
                        fileSize: fileSize,
                        sha256: hash,
                        needsSecurityScope: needsAccess
                    )
                }
            }
        } catch {
            if needsAccess { sourceURL.stopAccessingSecurityScopedResource() }
            log.error("sendFile failed: \(error.localizedDescription)")
        }
    }

    private func startFileSend(
        to device: Device,
        historyID: UUID,
        sourceURL: URL,
        fileSize: UInt64,
        sha256: String,
        needsSecurityScope: Bool
    ) {
        let transferID = UUID()
        let conn = Connection(connectingTo: device)
        let payload = ConnectionContext.ClientPayload.file(
            sourceURL: sourceURL,
            fileSize: fileSize,
            sha256: sha256,
            needsSecurityScope: needsSecurityScope
        )
        let ctx = ConnectionContext(
            connection: conn,
            role: .client(target: device, payload: payload),
            state: .awaitingHelloAck
        )
        ctx.historyID = historyID
        ctx.transferID = transferID
        ctx.fileSize = fileSize
        contexts[ctx.id] = ctx
        updateHistoryStatus(historyID, status: .waitingApproval)
        startConnection(ctx)
    }

    // MARK: - 配对决定

    public func respondToPairing(_ requestID: UUID, decision: PairingDecision) {
        guard let req = pendingPairings.first(where: { $0.id == requestID }) else { return }
        pendingPairings.removeAll { $0.id == requestID }

        let entry = contexts.first { _, c in
            if case .awaitingPairApproval(let r) = c.state, r.id == requestID { return true }
            return false
        }
        guard let (ctxID, _) = entry else { return }
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
        }
    }

    public func revokeTrust(fingerprint: String) {
        Task { await trustStore.revoke(fingerprint); await refreshTrusted() }
    }

    // MARK: - 文件 Offer 决定

    public func respondToFileOffer(_ offerID: UUID, accept: Bool) {
        guard let offer = pendingFileOffers.first(where: { $0.id == offerID }) else { return }
        pendingFileOffers.removeAll { $0.id == offerID }

        // 找对应连接
        let entry = contexts.first { _, c in c.pendingOfferID == offerID }
        guard let (ctxID, ctx) = entry else { return }

        if !accept {
            // 发 REJECT 再关
            Task {
                let body = try? MessageCodec.encode(FileRejectMessage(
                    transfer_id: offer.id.uuidString,
                    index: 0,
                    reason: "user_declined"
                ))
                if let body { try? await ctx.connection.send(type: MessageType.fileReject, body: body) }
                await closeContext(id: ctxID, error: nil)
            }
            return
        }

        // 接受：创建保存路径 + 打开 file handle + 发 ACCEPT + 进入 receiving 状态
        let saveURL = Self.uniqueFileURL(
            in: Self.defaultSaveDir(for: offer.peer),
            fileName: offer.fileName
        )
        do {
            FileManager.default.createFile(atPath: saveURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: saveURL)
            ctx.fileHandle = handle
            ctx.savedURL = saveURL
            ctx.fileSize = offer.fileSize
            ctx.expectedSHA256 = offer.sha256
            ctx.transferID = offer.id
            ctx.pendingOfferID = nil
            ctx.state = .receivingFile

            // 创建历史项
            let item = HistoryItem(
                peer: offer.peer,
                direction: .incoming,
                kind: .file(name: offer.fileName, size: offer.fileSize, url: saveURL),
                status: .transferring(bytesDone: 0, bytesTotal: offer.fileSize)
            )
            history.insert(item, at: 0)
            ctx.historyID = item.id

            Task {
                let body = try? MessageCodec.encode(FileAcceptMessage(
                    transfer_id: offer.id.uuidString,
                    index: 0,
                    resume_offset: 0
                ))
                if let body {
                    try? await ctx.connection.send(type: MessageType.fileAccept, body: body)
                }
            }
        } catch {
            log.error("open save handle failed: \(error.localizedDescription)")
            Task { await closeContext(id: ctxID, error: error) }
        }
    }

    // MARK: - 入站连接

    private func acceptIncoming(_ nwConn: NWConnection) async {
        let conn = Connection(nwConnection: nwConn)
        let ctx = ConnectionContext(connection: conn, role: .server, state: .awaitingHello)
        contexts[ctx.id] = ctx
        let ctxID = ctx.id
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

    private func startConnection(_ ctx: ConnectionContext) {
        let ctxID = ctx.id
        Task {
            await ctx.connection.start(
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

    // MARK: - 消息路由

    private func handleMessage(type: UInt8, body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }

        switch (ctx.state, type) {
        case (.awaitingHello, MessageType.hello):
            await serverReceivedHello(body: body, contextID: contextID)

        case (.awaitingHelloAck, MessageType.helloAck):
            await clientReceivedAck(body: body, contextID: contextID)

        case (.awaitingFileAccept, MessageType.fileAccept):
            await clientStartSending(contextID: contextID)

        case (.awaitingFileAccept, MessageType.fileReject):
            if let hid = ctx.historyID {
                let reason = (try? MessageCodec.decode(FileRejectMessage.self, from: body).reason) ?? "rejected"
                updateHistoryStatus(hid, status: .failed("对方拒收: \(reason)"))
            }
            await closeContext(id: contextID, error: nil)

        case (.sendingFile, MessageType.fileComplete):
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
            await closeContext(id: contextID, error: nil)

        case (.ready, MessageType.text):
            handleReceivedText(body: body, contextID: contextID)

        case (.ready, MessageType.fileOffer):
            handleReceivedFileOffer(body: body, contextID: contextID)

        case (.receivingFile, MessageType.fileChunk):
            await handleReceivedChunk(body: body, contextID: contextID)

        case (_, MessageType.ping):
            try? await ctx.connection.send(type: MessageType.pong, body: Data("{}".utf8))

        case (_, MessageType.pong):
            break

        case (_, MessageType.fileCancel):
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .canceled) }
            await closeContext(id: contextID, error: nil)

        default:
            log.info("drop unexpected type=\(type) in state=\(String(describing: ctx.state))")
            await closeContext(id: contextID, error: nil)
        }
    }

    // MARK: - HELLO 握手

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
        guard Set<UInt8>([1]).intersection(hello.protocol_versions).max() != nil else {
            await closeContext(id: contextID, error: nil); return
        }
        let peer = Device(
            id: hello.id, name: hello.name, os: hello.os, model: hello.model,
            fingerprint: hello.fp, port: 0, protocolVersion: 1
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
            id: identity.id, name: displayName, os: .current,
            model: Self.systemModel(), fp: identity.fingerprint,
            protocol_versions: [1], selected_version: 1
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
        guard case .client(let target, let payload) = ctx.role else {
            await closeContext(id: contextID, error: nil); return
        }
        guard ack.fp == target.fingerprint else {
            log.info("server fp mismatch; closing")
            await closeContext(id: contextID, error: nil); return
        }
        ctx.peer = target

        switch payload {
        case .text(let content):
            // 发文本 → 等 200ms 让对方读完缓冲 → 关
            let msg = TextMessage(
                id: UUID().uuidString.lowercased(),
                content: content,
                ts: Int64(Date().timeIntervalSince1970)
            )
            do {
                let textBody = try MessageCodec.encode(msg)
                try await ctx.connection.send(type: MessageType.text, body: textBody)
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
                try? await Task.sleep(nanoseconds: 200_000_000)
                await ctx.connection.close()
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
            }

        case .file(let sourceURL, let fileSize, let sha256, _):
            // 发 FILE_OFFER → 等 FILE_ACCEPT
            let fileName = sourceURL.lastPathComponent
            let transferID = ctx.transferID ?? UUID()
            ctx.transferID = transferID
            let offer = FileOfferMessage(
                transfer_id: transferID.uuidString,
                files: [FileMeta(index: 0, name: fileName, size: fileSize, sha256: sha256)]
            )
            do {
                let offerBody = try MessageCodec.encode(offer)
                try await ctx.connection.send(type: MessageType.fileOffer, body: offerBody)
                ctx.state = .awaitingFileAccept
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
            }
        }
    }

    // MARK: - 文件发送：开始流式发 chunk

    private func clientStartSending(contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }
        guard case .client(_, .file(let sourceURL, let fileSize, _, _)) = ctx.role else { return }

        do {
            let handle = try FileHandle(forReadingFrom: sourceURL)
            ctx.fileHandle = handle
            ctx.state = .sendingFile
            if let hid = ctx.historyID {
                updateHistoryStatus(hid, status: .transferring(bytesDone: 0, bytesTotal: fileSize))
            }
            // 异步流式发送
            Task { await streamChunks(contextID: contextID) }
        } catch {
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
            await closeContext(id: contextID, error: error)
        }
    }

    private func streamChunks(contextID: UUID) async {
        guard let ctx = contexts[contextID],
              let handle = ctx.fileHandle,
              let transferID = ctx.transferID else { return }
        let fileSize = ctx.fileSize
        let chunkSize = 256 * 1024

        while ctx.sentBytes < fileSize {
            if ctx.state.isClosed { return }
            let remaining = fileSize - ctx.sentBytes
            let toRead = Int(min(UInt64(chunkSize), remaining))
            let data = handle.readData(ofLength: toRead)
            if data.isEmpty { break }

            let header = FileChunkHeader(
                transferID: transferID,
                index: 0,
                offset: ctx.sentBytes
            )
            let body = FileChunkHeader.encode(header, data: data)
            do {
                try await ctx.connection.send(type: MessageType.fileChunk, body: body)
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
                return
            }
            ctx.sentBytes += UInt64(data.count)
            if let hid = ctx.historyID {
                updateHistoryStatus(hid, status: .transferring(bytesDone: ctx.sentBytes, bytesTotal: fileSize))
            }
        }
        try? handle.close()
        ctx.fileHandle = nil
        // 等对方 FILE_COMPLETE
    }

    // MARK: - 接收

    private func handleReceivedText(body: Data, contextID: UUID) {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let text = try? MessageCodec.decode(TextMessage.self, from: body) else { return }
        let item = HistoryItem(
            peer: peer,
            direction: .incoming,
            kind: .text(text.content),
            status: .completed
        )
        history.insert(item, at: 0)
    }

    private func handleReceivedFileOffer(body: Data, contextID: UUID) {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let offer = try? MessageCodec.decode(FileOfferMessage.self, from: body),
              let first = offer.files.first,
              let transferUUID = UUID(uuidString: offer.transfer_id) else { return }

        let pending = PendingFileOffer(
            id: transferUUID,
            peer: peer,
            fileName: first.name,
            fileSize: first.size,
            sha256: first.sha256
        )
        ctx.pendingOfferID = pending.id
        pendingFileOffers.append(pending)
    }

    private func handleReceivedChunk(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID],
              let handle = ctx.fileHandle,
              let (_, payload) = FileChunkHeader.decode(body) else { return }

        do {
            try handle.write(contentsOf: payload)
        } catch {
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
            await closeContext(id: contextID, error: error)
            return
        }
        ctx.receivedBytes += UInt64(payload.count)
        if let hid = ctx.historyID {
            updateHistoryStatus(hid, status: .transferring(bytesDone: ctx.receivedBytes, bytesTotal: ctx.fileSize))
        }

        if ctx.receivedBytes >= ctx.fileSize {
            try? handle.close()
            ctx.fileHandle = nil
            // 校验 sha256
            if let saved = ctx.savedURL, let expected = ctx.expectedSHA256 {
                let actual = (try? Self.sha256OfFile(at: saved)) ?? ""
                if actual != expected {
                    if let hid = ctx.historyID {
                        updateHistoryStatus(hid, status: .failed("校验失败"))
                    }
                    try? FileManager.default.removeItem(at: saved)
                    await closeContext(id: contextID, error: nil)
                    return
                }
            }
            // 发 FILE_COMPLETE
            if let tid = ctx.transferID {
                let complete = FileCompleteMessage(transfer_id: tid.uuidString, index: 0)
                if let cbody = try? MessageCodec.encode(complete) {
                    try? await ctx.connection.send(type: MessageType.fileComplete, body: cbody)
                }
            }
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
            try? await Task.sleep(nanoseconds: 150_000_000)
            await closeContext(id: contextID, error: nil)
        }
    }

    // MARK: - 关闭与辅助

    private func closeContext(id: UUID, error: Error?) async {
        guard let ctx = contexts.removeValue(forKey: id) else { return }
        if case .awaitingPairApproval(let req) = ctx.state {
            pendingPairings.removeAll { $0.id == req.id }
        }
        if let pid = ctx.pendingOfferID {
            pendingFileOffers.removeAll { $0.id == pid }
        }
        // 释放 security scope
        if case .client(_, .file(let url, _, _, let needsAccess)) = ctx.role, needsAccess {
            url.stopAccessingSecurityScopedResource()
        }
        try? ctx.fileHandle?.close()
        ctx.fileHandle = nil
        ctx.state = .closed
        await ctx.connection.close()
        if let error {
            log.debug("ctx \(id) closed with error: \(error.localizedDescription)")
        }
    }

    private func updateHistoryStatus(_ id: UUID, status: TransferStatus) {
        if let idx = history.firstIndex(where: { $0.id == id }) {
            history[idx].status = status
        }
    }

    private func refreshTrusted() async {
        let snap = await trustStore.snapshot()
        await MainActor.run { self.trusted = snap }
    }

    // MARK: - SHA256 + 路径辅助

    nonisolated static func sha256OfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func defaultSaveDir(for peer: Device) -> URL {
        let fm = FileManager.default
        let documents = (try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = documents
            .appendingPathComponent("MeshDrop", isDirectory: true)
            .appendingPathComponent(peer.name.isEmpty ? peer.id : peer.name, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func uniqueFileURL(in dir: URL, fileName: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(fileName)
        if !fm.fileExists(atPath: candidate.path) { return candidate }
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var n = 1
        while true {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
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
        case client(target: Device, payload: ClientPayload)
    }

    enum ClientPayload {
        case text(String)
        case file(sourceURL: URL, fileSize: UInt64, sha256: String, needsSecurityScope: Bool)
    }

    enum State {
        case awaitingHello
        case awaitingPairApproval(PairingRequest)
        case awaitingHelloAck
        case awaitingFileAccept
        case sendingFile
        case ready
        case receivingFile
        case closed

        var isClosed: Bool {
            if case .closed = self { return true }; return false
        }
    }

    let id: UUID = UUID()
    let connection: Connection
    let role: Role
    var state: State
    var peer: Device?

    // 关联的历史记录与传输
    var historyID: UUID?
    var transferID: UUID?
    var pendingOfferID: UUID?

    // 文件 I/O
    var fileHandle: FileHandle?
    var fileSize: UInt64 = 0
    var sentBytes: UInt64 = 0
    var receivedBytes: UInt64 = 0
    var savedURL: URL?
    var expectedSHA256: String?

    init(connection: Connection, role: Role, state: State) {
        self.connection = connection
        self.role = role
        self.state = state
    }
}
