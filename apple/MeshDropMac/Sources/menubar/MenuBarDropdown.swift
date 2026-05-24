import SwiftUI

/// 常驻菜单栏 dropdown · drop target + Nearby + 6 项快捷操作。
struct MenuBarDropdown: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            dropTarget
            nearby
            Rectangle().fill(MeshDropColor.divider).frame(height: 1)
            actions
            footer
        }
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MeshDropColor.cardBg)
                .shadow(color: MeshDropColor.ink12, radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(MeshDropColor.divider, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            MeshDropLockup(size: 18)
            Spacer()
            Chip(text: "LAN", tone: .lime, mono: true)
            Chip(text: "E2E", tone: .outline, mono: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var dropTarget: some View {
        VStack(spacing: 8) {
            Text("⤓")
                .font(MeshDropFont.display(size: 26, weight: .bold))
                .foregroundStyle(MeshDropColor.limeDeep)
            Text("DROP HERE")
                .meshTag()
                .foregroundStyle(MeshDropColor.limeDeep)
            Text("拖入文件 / 图片 / 文字便签")
                .font(MeshDropFont.body(size: 11))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeshDropColor.limeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MeshDropColor.lime,
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var nearby: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("附近 · NEARBY")
                    .meshTag()
                    .foregroundStyle(MeshDropColor.textMuted)
                Spacer()
                Text("\(state.engineDevices.count)")
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            if state.engineDevices.isEmpty {
                Text(state.isScanning ? "扫描中…" : "附近暂无设备")
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                ForEach(state.engineDevices.prefix(4)) { dev in
                    DeviceCard(device: dev, selected: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            actionRow("快速发送 · Quick send",   "⌥⇧S", "paperplane")
            actionRow("剪贴板历史",               "⌥⇧V", "doc.on.clipboard")
            actionRow("配对新设备",               "⌥⇧P", "person.2.badge.key")
            actionRow("打开 MeshDrop",            "⌥⇧O", "macwindow")
            actionRow("设置…",                    "⌘,",  "gearshape")
            actionRow("退出 MeshDrop",            "⌘Q",  "power")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func actionRow(_ text: String, _ shortcut: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(MeshDropColor.textSecondary)
            Text(text)
                .font(MeshDropFont.body(size: 12))
                .foregroundStyle(MeshDropColor.textPrimary)
            Spacer()
            Text(shortcut)
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack {
            Circle().fill(state.isScanning ? MeshDropColor.flame : MeshDropColor.limeDeep).frame(width: 6, height: 6)
            Text("\(state.isScanning ? "SCANNING" : "ONLINE") · \(state.localIPSummary)")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
            Spacer()
            Text("FP \(state.localFingerprintShort)")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(MeshDropColor.cardBg2)
        )
    }
}
