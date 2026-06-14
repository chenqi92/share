import Foundation
import SwiftUI
import MeshDropKit
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "Gateway")

/// macOS 上 Web Gateway 的启停 + 配对码管理 + 端口持久化。
/// 包成 `ObservableObject` 直接给 SwiftUI 用。
@MainActor
final class GatewayService: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published var port: UInt16 = 7384
    @Published var enabled: Bool = true
    @Published private(set) var pairingCode: String

    private let gateway: WebGateway

    init() {
        // v0.1：用 WebGateway 内置 fallback HTML。后续真正的 web 端 build 产物
        // 会落到 apple/MeshDropMac/Resources/web-fallback/，那时再把 staticRoot 指过去。
        let cfg = WebGateway.Config(host: "0.0.0.0", port: 7384, staticRoot: nil)
        let gw = WebGateway(config: cfg, engine: ShareEngine.shared)
        self.gateway = gw
        self.pairingCode = gw.pairingCode
    }

    func startIfEnabled() {
        guard enabled, !isRunning else { return }
        do {
            try gateway.start()
            isRunning = gateway.isRunning
            // 监听异步 ready，2s 后再读一次实际状态
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { self?.isRunning = self?.gateway.isRunning ?? false }
            }
        } catch {
            isRunning = false
            log.error("WebGateway 启动失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        gateway.stop()
        isRunning = false
    }

    func toggle(enabled newValue: Bool) {
        enabled = newValue
        if newValue { startIfEnabled() } else { stop() }
    }

    func setPort(_ value: UInt16) {
        port = value
        gateway.setPort(value)
        if isRunning {
            stop()
            startIfEnabled()
        }
    }

    func rotateCode() {
        gateway.rotatePairingCode()
        pairingCode = gateway.pairingCode
    }

    /// 给 UI 用的友好展示形式：`LR4 · K7M`。
    var displayCode: String {
        WebGateway.display(code: pairingCode)
    }

    /// `https://<local-ip>:<port>` —— 走 TLS 1.3 自签证书。给 Settings 复制。
    var displayURL: String {
        let ip = Self.firstIPv4() ?? "localhost"
        return "https://\(ip):\(port)"
    }

    private static func firstIPv4() -> String? {
        LocalIP.primaryIPv4()
    }
}
