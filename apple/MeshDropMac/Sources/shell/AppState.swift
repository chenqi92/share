import SwiftUI
import Combine
import MeshDropKit

/// 主区路由 + 选中设备 + 选项卡 …… 整个 app 状态。
/// 数据全部投影自 `ShareEngine.shared`；列表为空时空态由各 page 自行展示。
enum MainTab: String, CaseIterable, Identifiable {
    case discovery, chat, transfers, history, clipboard, trust, settings
    case pairing, onboarding, receive, menubar, dragdrop
    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    // 路由 / 输入
    @Published var tab: MainTab = .discovery
    @Published var selectedDeviceID: String = ""
    @Published var searchQuery: String = ""
    @Published var displayName: String
    @Published var transferFilter: TransferState? = nil
    @Published var showDragOverlay: Bool = false
    @Published var dragFileSummary: String = ""

    // 投影自 ShareEngine 的 UI mock-shape 状态
    @Published private(set) var engineDevices: [MockDevice] = []
    @Published private(set) var engineHistory: [MockHistory] = []
    @Published private(set) var enginePairing: MockPendingPairing? = nil
    @Published private(set) var engineOffer: MockPendingOffer? = nil
    @Published private(set) var engineTrusted: [MockTrustedDevice] = []

    // 网络层状态（顶部 banner 用）
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastError: String? = nil

    private let engine: ShareEngine
    private var cancellables = Set<AnyCancellable>()

    init(engine: ShareEngine = .shared) {
        self.engine = engine
        self.displayName = engine.displayName
        bind()
    }

    private func bind() {
        engine.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self else { return }
                self.engineDevices = list.map { MockDevice.from($0, online: true) }
                if !list.contains(where: { $0.id == self.selectedDeviceID }) {
                    self.selectedDeviceID = list.first?.id ?? ""
                }
            }
            .store(in: &cancellables)

        engine.$history
            .receive(on: DispatchQueue.main)
            .map { items in items.map(MockHistory.from) }
            .assign(to: &$engineHistory)

        engine.$pendingPairings
            .receive(on: DispatchQueue.main)
            .map { reqs in reqs.first.map(MockPendingPairing.from) }
            .assign(to: &$enginePairing)

        engine.$pendingFileOffers
            .receive(on: DispatchQueue.main)
            .map { offers in offers.first.map(MockPendingOffer.from) }
            .assign(to: &$engineOffer)

        engine.$trusted
            .receive(on: DispatchQueue.main)
            .map { recs in recs.map { MockTrustedDevice.from($0) } }
            .assign(to: &$engineTrusted)

        engine.$isStarting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        engine.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastError)
    }

    // MARK: - 视觉用：本机 / 选中设备投影

    var selectedDevice: MockDevice {
        if let dev = engineDevices.first(where: { $0.id == selectedDeviceID }) {
            return dev
        }
        return engineDevices.first ?? MockDevice.placeholder
    }

    /// 本机信息（IP / OS / 指纹 / 可见性）。
    var localIPSummary: String {
        Self.firstIPv4() ?? "—"
    }

    var localFingerprintShort: String {
        let fp = engine.identity.fingerprint.uppercased()
        var groups: [String] = []
        var i = fp.startIndex
        while i < fp.endIndex && groups.count < 4 {
            let e = fp.index(i, offsetBy: 4, limitedBy: fp.endIndex) ?? fp.endIndex
            groups.append(String(fp[i..<e]))
            i = e
        }
        return groups.joined(separator: " · ")
    }

    var localFingerprintFull: String {
        let fp = engine.identity.fingerprint.uppercased()
        var groups: [String] = []
        var i = fp.startIndex
        while i < fp.endIndex {
            let e = fp.index(i, offsetBy: 4, limitedBy: fp.endIndex) ?? fp.endIndex
            groups.append(String(fp[i..<e]))
            i = e
        }
        return groups.joined(separator: " · ")
    }

    // MARK: - 命令转发

    func sendText(toDeviceID deviceID: String, content: String) {
        guard let dev = engine.devices.first(where: { $0.id == deviceID }) else { return }
        engine.sendText(to: dev, content: content)
    }

    func sendFile(toDeviceID deviceID: String, fileURL: URL) {
        guard let dev = engine.devices.first(where: { $0.id == deviceID }) else { return }
        engine.sendFile(to: dev, sourceURL: fileURL)
    }

    func acceptCurrentPairing(trust: Bool) {
        guard let id = enginePairing.flatMap({ UUID(uuidString: $0.id) }) else { return }
        engine.respondToPairing(id, decision: trust ? .trust : .allowOnce)
    }

    func rejectCurrentPairing() {
        guard let id = enginePairing.flatMap({ UUID(uuidString: $0.id) }) else { return }
        engine.respondToPairing(id, decision: .reject)
    }

    func acceptCurrentOffer() {
        guard let id = engineOffer.flatMap({ UUID(uuidString: $0.id) }) else { return }
        engine.respondToFileOffer(id, accept: true)
    }

    func rejectCurrentOffer() {
        guard let id = engineOffer.flatMap({ UUID(uuidString: $0.id) }) else { return }
        engine.respondToFileOffer(id, accept: false)
    }

    func clearHistory() {
        engine.clearHistory()
    }

    func removeHistoryItem(_ historyID: String) {
        guard let uuid = UUID(uuidString: historyID) else { return }
        engine.removeHistoryItem(uuid)
    }

    func revokeTrust(fingerprint: String) {
        engine.revokeTrust(fingerprint: fingerprint)
    }

    func clearError() {
        engine.clearLastError()
    }

    func applyDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        engine.setDisplayName(trimmed)
        displayName = trimmed
    }

    // MARK: - 网络辅助

    private static func firstIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = first
        var candidate: String?
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if (flags & (IFF_UP|IFF_RUNNING)) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let res = getnameinfo(
                        ptr.pointee.ifa_addr,
                        socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                        &hostBuf, socklen_t(hostBuf.count),
                        nil, 0, NI_NUMERICHOST
                    )
                    if res == 0 {
                        let host = String(cString: hostBuf)
                        if !host.hasPrefix("127.") && !host.hasPrefix("169.254.") {
                            candidate = host
                        }
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return candidate
    }
}

extension MockDevice {
    static let placeholder = MockDevice(
        id: "—",
        name: "等待发现…",
        who: "—",
        kind: .mac,
        dist: 0,
        angle: 0,
        color: Color(hex: 0xE2DCCD),
        initials: "—",
        os: "—",
        rtt: 0,
        online: false
    )
}
