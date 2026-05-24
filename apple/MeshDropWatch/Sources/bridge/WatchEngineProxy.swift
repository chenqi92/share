import Foundation
import Combine
import OSLog

/// Watch 端的 "Engine 代理"。API 形状对齐 [ShareEngine]（iPhone 端 / Mac 端的真 Engine），
/// 让 UI 切换时只改类型即可，不感知底层是 LAN 直连还是 WatchConnectivity 中转。
///
/// 重要：watch 上**没有** LAN，所有 `devices` / `history` / `pendingOffers` 都是 iPhone 桥接侧
/// 通过事件推过来的快照。如果 `isOnline == false`（companion 不在身边），UI 应进入 OFFLINE 态，
/// 禁用所有发送 CTA。
@MainActor
final class WatchEngineProxy: ObservableObject {

    static let shared = WatchEngineProxy()

    // MARK: - Published 状态（UI 绑定）

    /// 桥接通道是否可达（companion iPhone 在身边）。**不是** LAN 状态——LAN 状态 watch 不感知。
    @Published private(set) var isOnline: Bool = false

    /// 当前 bridge 是否在初始化（activation 中 / 第一次同步快照中）。
    @Published private(set) var isStarting: Bool = false

    /// 最近一次错误（命令超时 / 网络异常 / activation 失败）。
    @Published var lastError: String?

    /// LAN 设备清单（iPhone 桥接侧来的）。
    @Published private(set) var devices: [BridgeDevice] = []

    /// 历史（双向）。
    @Published private(set) var history: [BridgeHistoryItem] = []

    /// 待审 incoming file offer。
    @Published private(set) var pendingOffers: [BridgeOffer] = []

    /// 待审配对请求。
    @Published private(set) var pendingPairings: [BridgePairing] = []

    /// 进行中的 transfer（key = id）。
    @Published private(set) var transfers: [String: BridgeTransferProgress] = [:]

    // MARK: - 内部

    private let client = WatchSessionClient()
    private let log = Logger(subsystem: "com.welape.meshdrop", category: "WatchEngineProxy")
    private var didStart = false

    private init() {}

    // MARK: - 生命周期

    func start() {
        guard !didStart else { return }
        didStart = true
        isStarting = true

        client.onReachabilityChanged = { [weak self] reachable in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isOnline = reachable
                if reachable {
                    self.lastError = nil
                    await self.requestSnapshot()
                }
            }
        }

        client.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.apply(event)
            }
        }

        client.onActivationCompleted = { [weak self] ok, err in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isStarting = false
                if let err {
                    self.lastError = "桥接初始化失败：\(err)"
                }
                if ok {
                    await self.requestSnapshot()
                }
            }
        }

        client.start()
    }

    // MARK: - 命令（对齐 ShareEngine）

    /// 发文本。
    func sendText(to peerId: String, text: String) async throws {
        let cmd = BridgeCommand(
            type: .sendText,
            payload: [
                "peerId": AnyCodable(peerId),
                "text": AnyCodable(text),
            ]
        )
        try await dispatch(cmd)
    }

    /// 发文件（watch 端先 transferFile，iPhone 收到后再走 LAN 发给 peer）。
    func sendFileRef(to peerId: String, fileURL: URL, name: String) async throws {
        _ = try client.transferFile(at: fileURL, peerId: peerId, name: name)
    }

    func acceptOffer(_ offerId: String) async throws {
        let cmd = BridgeCommand(type: .acceptOffer, payload: ["offerId": AnyCodable(offerId)])
        try await dispatch(cmd)
        pendingOffers.removeAll { $0.id == offerId }
    }

    func rejectOffer(_ offerId: String) async throws {
        let cmd = BridgeCommand(type: .rejectOffer, payload: ["offerId": AnyCodable(offerId)])
        try await dispatch(cmd)
        pendingOffers.removeAll { $0.id == offerId }
    }

    func acceptPairing(_ pairingId: String, trust: Bool) async throws {
        let cmd = BridgeCommand(
            type: .acceptPairing,
            payload: [
                "pairingId": AnyCodable(pairingId),
                "trust": AnyCodable(trust),
            ]
        )
        try await dispatch(cmd)
        pendingPairings.removeAll { $0.id == pairingId }
    }

    func rejectPairing(_ pairingId: String) async throws {
        let cmd = BridgeCommand(type: .rejectPairing, payload: ["pairingId": AnyCodable(pairingId)])
        try await dispatch(cmd)
        pendingPairings.removeAll { $0.id == pairingId }
    }

    func clearHistory(scope: String = "all") async throws {
        let cmd = BridgeCommand(type: .clearHistory, payload: ["scope": AnyCodable(scope)])
        try await dispatch(cmd)
        history.removeAll()
    }

    func deleteHistoryItem(_ id: String) async throws {
        let cmd = BridgeCommand(type: .deleteHistoryItem, payload: ["itemId": AnyCodable(id)])
        try await dispatch(cmd)
        history.removeAll { $0.id == id }
    }

    // MARK: - 内部派发

    private func dispatch(_ command: BridgeCommand) async throws {
        do {
            let ack = try await client.sendCommand(command)
            if !ack.ok {
                lastError = ack.error ?? "命令失败"
                throw NSError(
                    domain: "WatchEngineProxy", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: lastError ?? "命令失败"]
                )
            }
            lastError = nil
        } catch let e as WatchSessionClient.BridgeError {
            lastError = e.errorDescription
            throw e
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func requestSnapshot() async {
        do {
            let ack = try await client.sendCommand(BridgeCommand(type: .getState))
            guard ack.ok, let result = ack.result else { return }
            ingestSnapshot(result)
        } catch {
            // 静默失败：iPhone 端可能还没装 WatchBridge（B02 未合）；
            // UI 仍可保持 OFFLINE 态，等下次 reachability 变化再试。
            log.notice("get_state 失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    private func ingestSnapshot(_ result: [String: AnyCodable]) {
        if let raw = result["devices"]?.value as? [Any?] {
            devices = decodeArray(BridgeDevice.self, from: raw)
        }
        if let raw = result["history"]?.value as? [Any?] {
            history = decodeArray(BridgeHistoryItem.self, from: raw)
        }
        if let raw = result["pendingOffers"]?.value as? [Any?] {
            pendingOffers = decodeArray(BridgeOffer.self, from: raw)
        }
        if let raw = result["pendingPairings"]?.value as? [Any?] {
            pendingPairings = decodeArray(BridgePairing.self, from: raw)
        }
    }

    private func decodeArray<T: Decodable>(_ type: T.Type, from raw: [Any?]) -> [T] {
        raw.compactMap { item -> T? in
            guard let dict = item as? [String: Any] else { return nil }
            return try? BridgeCodec.decode(T.self, from: dict)
        }
    }

    private func apply(_ event: BridgeEvent) {
        let payload = event.payload
        switch event.type {
        case .deviceAdded, .deviceUpdated:
            if let device = try? BridgeCodec.decode(BridgeDevice.self, fromPayload: payload) {
                if let idx = devices.firstIndex(where: { $0.id == device.id }) {
                    devices[idx] = device
                } else {
                    devices.append(device)
                }
            }
        case .deviceRemoved:
            if let id = payload["id"]?.value as? String {
                devices.removeAll { $0.id == id }
            }
        case .pairingPending:
            if let p = try? BridgeCodec.decode(BridgePairing.self, fromPayload: payload) {
                pendingPairings.append(p)
            }
        case .offerPending:
            if let offer = try? BridgeCodec.decode(BridgeOffer.self, fromPayload: payload) {
                pendingOffers.append(offer)
            }
        case .transferProgress:
            if let p = try? BridgeCodec.decode(BridgeTransferProgress.self, fromPayload: payload) {
                transfers[p.id] = p
            }
        case .transferDone:
            if let id = payload["id"]?.value as? String {
                transfers.removeValue(forKey: id)
            }
        case .historyAdded:
            if let item = try? BridgeCodec.decode(BridgeHistoryItem.self, fromPayload: payload) {
                history.insert(item, at: 0)
            }
        }
    }
}
