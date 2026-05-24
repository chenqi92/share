import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var visible: Bool = true
    @State private var requireConfirm: Bool = true
    @State private var autoAcceptTrusted: Bool = true
    @State private var notifyOnArrival: Bool = true
    @State private var trustNewFor: Int = 1

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader("可见性 · Visibility")
                    visibilityCard
                    sectionHeader("安全 / 加密 · Security")
                    securityCard
                    sectionHeader("行为 / 接收 · Behavior")
                    behaviorCard
                    sectionHeader("关于 · About")
                    aboutCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
        }
        .navigationTitle("设置 · Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("完成") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ s: String) -> some View {
        AsciiDivider(s)
    }

    private var visibilityCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $visible) {
                row(title: "可见", detail: visible ? "附近设备可发现我" : "完全隐身")
            }
            .tint(MeshDropColor.lime)
            .padding(14)
            divider
            HStack {
                row(title: "本机名", detail: Mock.me.name)
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var securityCard: some View {
        VStack(spacing: 0) {
            HStack {
                row(title: "端到端加密", detail: "X25519 + ChaCha20-Poly1305")
                Spacer()
                Chip("E2E", tone: .lime, mono: true, uppercased: true)
            }
            .padding(14)
            divider
            HStack {
                row(title: "本机指纹", detail: Mock.me.fingerprint)
                Spacer()
                IconBtn("doc.on.doc", size: 28, variant: .ghost)
            }
            .padding(14)
            divider
            HStack {
                row(title: "信任管理", detail: "5 台已配对")
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var behaviorCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $requireConfirm) {
                row(title: "新设备需要确认", detail: "陌生设备发文件时弹审批")
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            Toggle(isOn: $autoAcceptTrusted) {
                row(title: "信任设备自动接收", detail: "小于 5 MB 自动接收")
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            Toggle(isOn: $notifyOnArrival) {
                row(title: "到达通知", detail: "横幅 / 锁屏 / Dynamic Island")
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            HStack {
                row(title: "保存到", detail: "Files / MeshDrop 收件箱")
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            HStack {
                row(title: "版本", detail: "0.1.0 · build 1")
                Spacer()
            }
            .padding(14)
            divider
            HStack {
                row(title: "服务类型", detail: "_meshdrop._tcp")
                Spacer()
            }
            .padding(14)
            divider
            HStack {
                row(title: "Bundle id", detail: "com.welape.landrop")
                Spacer()
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private func row(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(MeshDropFont.body(14.5, weight: .semibold))
            Text(detail).font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                .lineLimit(1)
        }
    }

    private var divider: some View {
        Rectangle().fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line)
            .frame(height: 0.5).padding(.leading, 14)
    }

    private var sectionBg: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
    }
}
