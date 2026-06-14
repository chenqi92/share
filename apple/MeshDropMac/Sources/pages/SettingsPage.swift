import SwiftUI
import MeshDropKit

struct SettingsPage: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var gateway: GatewayService
    @ObservedObject private var engine = ShareEngine.shared
    @State private var keepHistoryDays = 30
    @State private var displayNameEdit = ""
    @State private var confirmingReset = false

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
                    Chip(text: "v 0.1.0", tone: .outline, mono: true)
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
                    // 尚未接 engine 持久化/生效逻辑，禁用并标注，避免给「已设置」错觉。
                    disabledToggle(String(localized: "settings.visibleOnLan"), on: true)
                    disabledToggle(String(localized: "settings.pairedOnly"), on: false)
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
                    // 安全开关：engine 暂未提供持久化入口，禁用并标注，避免安全预期落空。
                    disabledToggle(String(localized: "settings.security.verifyBeforeReceive"), on: true)
                    disabledToggle(String(localized: "settings.security.confirmStranger"), on: true)
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
                    // 安全相关开关，engine 暂无对应能力 —— 禁用并标注，避免误以为已开启自动接受。
                    disabledToggle(String(localized: "settings.receive.autoAcceptStranger"), on: false)
                    field(String(localized: "settings.receive.defaultPath"), trailing:
                        Text("~/Documents/MeshDrop/")
                            .font(MeshDropFont.mono(size: 12))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section(String(localized: "settings.section.clipboard")) {
                    disabledToggle(String(localized: "settings.clipboard.enableSync"), on: true)
                    field(String(localized: "settings.clipboard.keepDuration"), trailing:
                        Text("settings.clipboard.keepDuration.value")
                            .font(MeshDropFont.mono(size: 12))
                            .foregroundStyle(MeshDropColor.textSecondary)
                    )
                }

                section(String(localized: "settings.section.behavior")) {
                    disabledToggle(String(localized: "settings.behavior.launchAtLogin"), on: true)
                    disabledToggle(String(localized: "settings.behavior.showInMenuBar"), on: true)
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
        .onAppear { if displayNameEdit.isEmpty { displayNameEdit = state.displayName } }
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

    /// 尚未接入 engine 生效逻辑的开关：固定展示状态、禁用交互、标注「即将支持」，
    /// 不让用户误以为切换有效果（尤其安全相关项）。
    @ViewBuilder
    private func disabledToggle(_ label: String, on: Bool) -> some View {
        HStack {
            Text(label)
                .font(MeshDropFont.body(size: 12.5))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("settings.soon")
                .font(MeshDropFont.mono(size: 9, weight: .semibold))
                .foregroundStyle(MeshDropColor.textMuted)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MeshDropColor.divider, lineWidth: 0.5)
                )
            Spacer()
            MeshToggle(on: .constant(on))
                .opacity(0.4)
                .allowsHitTesting(false)
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
