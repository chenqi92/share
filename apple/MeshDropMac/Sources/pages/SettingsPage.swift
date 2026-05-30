import SwiftUI
import MeshDropKit

struct SettingsPage: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var gateway: GatewayService
    @ObservedObject private var engine = ShareEngine.shared
    @State private var visibleToAll = true
    @State private var requireFingerprint = true
    @State private var autoAcceptUntrusted = false
    @State private var clipboardSync = true
    @State private var startAtLogin = true
    @State private var showInMenuBar = true
    @State private var keepHistoryDays = 30
    @State private var displayNameEdit = ""
    @State private var confirmingReset = false

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("设置")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("· Settings")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    Chip(text: "v 0.1.0", tone: .outline, mono: true)
                }

                section("可见性 · Visibility") {
                    HStack {
                        Text("显示名称")
                            .font(MeshDropFont.body(size: 12.5))
                            .foregroundStyle(MeshDropColor.textPrimary)
                        Spacer(minLength: 12)
                        TextField("", text: $displayNameEdit, onCommit: {
                            state.applyDisplayName(displayNameEdit)
                        })
                        .textFieldStyle(.roundedBorder)
                        .font(MeshDropFont.body(size: 13, weight: .semibold))
                        .frame(width: 240)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    toggle("局域网可见 · Visible on LAN", on: $visibleToAll)
                    toggle("仅显示已配对设备", on: .constant(false))
                    field("设备类型", trailing:
                        Text("MAC · macOS")
                            .font(MeshDropFont.mono(size: 12, weight: .semibold))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section("安全 · Security") {
                    field("指纹（X25519）", trailing:
                        Text(state.localFingerprintFull)
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textSecondary)
                            .frame(width: 380, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    )
                    toggle("接收前必须验证对方指纹", on: $requireFingerprint)
                    toggle("陌生设备首次配对要求确认", on: .constant(true))
                    Button("查看 / 复制完整指纹 · QR 码…") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.localFingerprintFull, forType: .string)
                    }
                    .buttonStyle(.plain)
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(MeshDropColor.limeDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MeshDropColor.divider, lineWidth: 1)
                    )
                    Button("重置身份…") {
                        confirmingReset = true
                    }
                    .buttonStyle(.plain)
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(MeshDropColor.flame)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MeshDropColor.flame.opacity(0.4), lineWidth: 1)
                    )
                    .confirmationDialog(
                        "重置身份会生成新的 ID 与密钥对，所有已配对的对端会把本机视为新设备需要重新配对。继续？",
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button("重置身份", role: .destructive) {
                            ShareEngine.shared.resetIdentity()
                        }
                        Button("取消", role: .cancel) {}
                    }
                }

                section("Web 访问 · Web Gateway") {
                    PairingCodeView()
                }

                section("接收 · Receive") {
                    toggle("已配对设备自动接受", on: $engine.autoAcceptFromTrusted)
                    toggle("陌生设备自动接受（不建议）", on: $autoAcceptUntrusted)
                    field("默认存放路径", trailing:
                        Text("~/Downloads/MeshDrop/")
                            .font(MeshDropFont.mono(size: 12))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section("剪贴板 · Clipboard") {
                    toggle("启用跨设备剪贴板同步", on: $clipboardSync)
                    field("保留时间", trailing:
                        Text("24 小时 · 自动清理")
                            .font(MeshDropFont.mono(size: 12))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section("行为 · Behavior") {
                    toggle("登录时启动", on: $startAtLogin)
                    toggle("显示在菜单栏", on: $showInMenuBar)
                    field("历史保留天数", trailing:
                        Text("\(keepHistoryDays) 天")
                            .font(MeshDropFont.mono(size: 12, weight: .semibold))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section("关于 · About") {
                    HStack(alignment: .top, spacing: 14) {
                        MeshDropMark(size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            MeshDropWordmark(size: 26)
                            Text("Space Grotesk · Geist · Geist Mono")
                                .font(MeshDropFont.mono(size: 11))
                                .foregroundStyle(MeshDropColor.textMuted)
                            Text("局域网分享 · E2E X25519+ChaCha20 · 仅 LAN")
                                .font(MeshDropFont.mono(size: 11))
                                .foregroundStyle(MeshDropColor.textMuted)
                            Text("© 2026 MeshDrop · v 0.1.0")
                                .font(MeshDropFont.mono(size: 10))
                                .foregroundStyle(MeshDropColor.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
        .onAppear { if displayNameEdit.isEmpty { displayNameEdit = state.displayName } }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .meshTag()
                .foregroundStyle(MeshDropColor.textMuted)
            VStack(spacing: 1) {
                content()
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MeshDropColor.cardBg)
            )
        }
    }

    @ViewBuilder
    private func field<T: View>(_ label: String, trailing: T) -> some View {
        HStack {
            Text(label)
                .font(MeshDropFont.body(size: 12.5))
                .foregroundStyle(MeshDropColor.textPrimary)
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func toggle(_ label: String, on: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(MeshDropFont.body(size: 12.5))
                .foregroundStyle(MeshDropColor.textPrimary)
            Spacer()
            MeshToggle(on: on)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// 自定义 lime 风格 toggle。
struct MeshToggle: View {
    @Binding var on: Bool

    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? MeshDropColor.lime : MeshDropColor.divider)
                .frame(width: 38, height: 22)
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .padding(2)
                .shadow(color: MeshDropColor.ink12, radius: 1)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                on.toggle()
            }
        }
    }
}
