import SwiftUI
import MeshDropKit

struct SettingsPage: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var gateway: GatewayService
    @ObservedObject private var engine = ShareEngine.shared
    @State private var keepHistoryDays = 30
    @State private var displayNameEdit = ""
    @State private var confirmingReset = false
    @State private var pathSelectionError: String?
    /// 「登录时启动」回显以系统真实登录项状态为准（onAppear 同步），开关动作走 SMAppService。
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("settings.title")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("settings.title.suffix")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    Chip(text: "v 1.0.1", tone: .outline, mono: true)
                }

                section(String(localized: "settings.section.visibility")) {
                    HStack {
                        Text("settings.displayName")
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
                    // 局域网可见：开=广告 mDNS 可被发现；关=停止广告（已建连接不强断）。即时生效。
                    toggle(String(localized: "settings.visibleOnLan"), on: $engine.visibleOnLan)
                    // 仅显示已配对设备（trusted-only）：开=只对信任库 fp 回 ACK，未知 fp 关连接。
                    toggle(String(localized: "settings.pairedOnly"), on: $engine.trustedOnly)
                    field(String(localized: "settings.deviceType"), trailing:
                        Text("MAC · macOS")
                            .font(MeshDropFont.mono(size: 12, weight: .semibold))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section(String(localized: "settings.section.security")) {
                    field(String(localized: "settings.security.fingerprint"), trailing:
                        Text(state.localFingerprintFull)
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textSecondary)
                            .frame(width: 380, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    )
                    // 接收前必须验证对方指纹：开（默认）=禁用一切自动接受，offer 一律进待确认。
                    toggle(String(localized: "settings.security.verifyBeforeReceive"), on: $engine.verifyBeforeReceive)
                    // 陌生设备首次配对要求确认：TOFU 是安全基线，关闭等于自动信任陌生设备（危险），
                    // 故锁定为始终开启并加说明，而不是留作可关的假开关。
                    lockedOnToggle(
                        String(localized: "settings.security.confirmStranger"),
                        note: String(localized: "settings.note.alwaysOn")
                    )
                    HStack(spacing: 10) {
                        Button("settings.security.copyFingerprint") {
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
                        Button("settings.security.resetIdentity") {
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
                            "settings.security.resetIdentity.confirm.title",
                            isPresented: $confirmingReset,
                            titleVisibility: .visible
                        ) {
                            Button("settings.security.resetIdentity.confirm.button", role: .destructive) {
                                ShareEngine.shared.resetIdentity()
                            }
                            Button("common.cancel", role: .cancel) {}
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }

                section(String(localized: "settings.section.webGateway")) {
                    PairingCodeView()
                }

                section(String(localized: "settings.section.receive")) {
                    toggle(String(localized: "settings.receive.autoAcceptTrusted"), on: $engine.autoAcceptFromTrusted)
                    // 陌生设备自动接受（危险，默认关）。仅在「接收前验证指纹」关闭时才会真正生效，
                    // 故验证开启时灰显锁定，避免「已开但无效」的错觉。
                    gatedToggle(
                        String(localized: "settings.receive.autoAcceptStranger"),
                        on: $engine.autoAcceptStranger,
                        enabled: !engine.verifyBeforeReceive
                    )
                    field(String(localized: "settings.receive.defaultPath"), trailing:
                        HStack(spacing: 10) {
                            Text(receiveDirectoryDisplayPath)
                                .font(MeshDropFont.mono(size: 12))
                                .foregroundStyle(MeshDropColor.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 300, alignment: .trailing)
                            Button("settings.receive.changePath") {
                                chooseReceiveDirectory()
                            }
                            .controlSize(.small)
                        }
                    )
                }

                section(String(localized: "settings.section.clipboard")) {
                    // 跨设备剪贴板同步总开关：关=不发不收剪贴板（门控已有 push/handle 收发）。
                    toggle(String(localized: "settings.clipboard.enableSync"), on: $engine.clipboardSyncEnabled)
                    field(String(localized: "settings.clipboard.keepDuration"), trailing:
                        Text("settings.clipboard.keepDuration.value")
                            .font(MeshDropFont.mono(size: 12))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section(String(localized: "settings.section.behavior")) {
                    // 登录时启动：真实注册到系统登录项（SMAppService），回显以系统状态为准。
                    toggle(String(localized: "settings.behavior.launchAtLogin"), on: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            LoginItemManager.setEnabled(newValue)
                            // 以系统真实状态回写，注册失败 / 需批准时不会留下错误的「已开」假象。
                            launchAtLogin = LoginItemManager.isEnabled || newValue
                        }
                    ))
                    // 显示在菜单栏：当前菜单栏项常驻（SwiftUI MenuBarExtra(isInserted:) 有启动卡死
                    // 的 bug，显隐开关需改用手动 NSStatusItem，留待后续），先锁定为常显并标注。
                    lockedOnToggle(
                        String(localized: "settings.behavior.showInMenuBar"),
                        note: String(localized: "settings.note.alwaysOn")
                    )
                    field(String(localized: "settings.behavior.keepHistoryDays"), trailing:
                        Text(String(format: String(localized: "settings.behavior.keepHistoryDays.value"), keepHistoryDays))
                            .font(MeshDropFont.mono(size: 12, weight: .semibold))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section(String(localized: "settings.section.about")) {
                    HStack(alignment: .top, spacing: 14) {
                        MeshDropMark(size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            MeshDropWordmark(size: 26)
                            Text("about.fonts")
                                .font(MeshDropFont.mono(size: 11))
                                .foregroundStyle(MeshDropColor.textMuted)
                            Text("about.tagline")
                                .font(MeshDropFont.mono(size: 11))
                                .foregroundStyle(MeshDropColor.textMuted)
                            Text("about.copyright")
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
        .onAppear {
            if displayNameEdit.isEmpty { displayNameEdit = state.displayName }
            // 以系统真实登录项状态回显（用户可能在系统设置里手动改过）。
            launchAtLogin = LoginItemManager.isEnabled
        }
        .alert(
            String(localized: "settings.receive.pathError.title"),
            isPresented: Binding(
                get: { pathSelectionError != nil },
                set: { if !$0 { pathSelectionError = nil } }
            )
        ) {
            Button("common.close", role: .cancel) { pathSelectionError = nil }
        } message: {
            Text(pathSelectionError ?? "")
        }
    }

    private var receiveDirectoryDisplayPath: String {
        (engine.receiveDirectoryURL.path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseReceiveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = engine.receiveDirectoryURL
        panel.title = String(localized: "settings.receive.pathPicker.title")
        panel.prompt = String(localized: "settings.receive.pathPicker.prompt")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        do {
            try engine.setReceiveDirectory(selectedURL)
            pathSelectionError = nil
        } catch {
            pathSelectionError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .meshTag()
                .foregroundStyle(MeshDropColor.textMuted)
            VStack(alignment: .leading, spacing: 1) {
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
        HStack(alignment: .firstTextBaseline) {
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

    /// 开关 + 下方小字说明（如「重启后生效」），交互正常。
    @ViewBuilder
    private func noteToggle(_ label: String, on: Binding<Bool>, note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(MeshDropFont.body(size: 12.5))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text(note)
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            Spacer()
            MeshToggle(on: on)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 永远开启且不可关闭的安全开关：保持开态、禁用交互、给出原因说明，
    /// 不留「可关」的危险假象（如关闭 TOFU 会自动信任陌生设备）。
    @ViewBuilder
    private func lockedOnToggle(_ label: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(MeshDropFont.body(size: 12.5))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text(note)
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            Spacer()
            MeshToggle(on: .constant(true))
                .opacity(0.55)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 受前置条件门控的开关：`enabled=false` 时灰显锁定（仍展示当前持久化值，但不可改），
    /// 避免「已开但当前无效」的错觉。用于「陌生设备自动接受」依赖「关闭接收前验证」。
    @ViewBuilder
    private func gatedToggle(_ label: String, on: Binding<Bool>, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .font(MeshDropFont.body(size: 12.5))
                .foregroundStyle(enabled ? MeshDropColor.textPrimary : MeshDropColor.textMuted)
            Spacer()
            MeshToggle(on: on)
                .opacity(enabled ? 1 : 0.4)
                .allowsHitTesting(enabled)
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
