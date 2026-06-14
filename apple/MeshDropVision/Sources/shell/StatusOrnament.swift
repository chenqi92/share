import SwiftUI
import MeshDropKit

/// 主窗口顶部 ornament：身份 + 网络 + 指纹缩写 + 传输状态标识 + scanning pill。
struct StatusOrnament: View {
    @EnvironmentObject private var engine: ShareEngine
    @State private var confirmingReset: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Avatar(initials: "我", color: MD.lime, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(engine.displayName)
                        .font(MDFont.label)
                        .foregroundStyle(MD.dpaper)
                    Text(localHost())
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }
            }

            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.6, height: 22)

            if engine.isStarting {
                Chip(text: "SCANNING · 192.168 · 房间",
                     tone: .outline, mono: true, leadingDot: MD.lime)
            } else if engine.devices.isEmpty {
                Chip(text: "VISIBLE · 等待设备",
                     tone: .outline, mono: true, leadingDot: MD.lime)
            } else {
                Chip(text: "VISIBLE · \(engine.devices.count) 台",
                     tone: .lime, mono: true, leadingDot: MD.limeDeep)
            }
            if let err = engine.lastError {
                Chip(text: "ERR · \(err.prefix(28))",
                     tone: .flame, mono: true, leadingDot: MD.flame)
            }
            Chip(text: "LAN · 明文", tone: .outline, mono: true)
            Chip(text: "v0.1", tone: .outline, mono: true)

            Spacer().frame(width: 8)

            HStack(spacing: 6) {
                Image(systemName: "fingerprint")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MD.dpaper.opacity(0.6))
                Text(shortFingerprint(of: engine.identity.fingerprint))
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.78))
            }
            .contextMenu {
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("重置身份…", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassBackgroundEffect(in: Capsule())
        .confirmationDialog(
            "重置身份会生成新的 ID 与密钥对，所有已配对的对端会把本机视为新设备需要重新配对。继续？",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("重置身份", role: .destructive) { engine.resetIdentity() }
            Button("取消", role: .cancel) {}
        }
    }

    /// 简单的本机主机名（不是 IP，因为 visionOS 上拿 IP 受限；显示主机名同样可识别）。
    private func localHost() -> String {
        ProcessInfo.processInfo.hostName
    }

    /// 把 32 hex 指纹切成 4 字符一组，取前 4 组：`ZX8K · L72M · 9FQ3 · 7HD2`。
    private func shortFingerprint(of fp: String) -> String {
        let upper = fp.uppercased()
        var chunks: [String] = []
        var idx = upper.startIndex
        while idx < upper.endIndex && chunks.count < 4 {
            let end = upper.index(idx, offsetBy: 4, limitedBy: upper.endIndex) ?? upper.endIndex
            chunks.append(String(upper[idx..<end]))
            idx = end
        }
        return chunks.joined(separator: " · ")
    }
}
