import SwiftUI

struct DiscoverTab: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    heroBlock
                    radarBlock
                    deviceListBlock
                    quickStripBlock
                    AsciiDivider("LAN · 192.168.1.0/24 · LIVE")
                    statusBar
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            MeshDropLockup(size: 18)
            Spacer()
            Chip("LIVE", tone: .lime, mono: true, uppercased: true, icon: "circle.fill")
            IconBtn("line.3.horizontal", size: 32, variant: .ghost) {
                state.showSettings = true
            }
        }
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("附近")
                    .font(MeshDropFont.display(34, weight: .bold))
                Text("\(Mock.devices.filter(\.isOnline).count) 台")
                    .font(MeshDropFont.mono(14, weight: .semibold))
                    .foregroundStyle(MeshDropColor.flame)
            }
            HStack(spacing: 6) {
                Text("Nearby devices.")
                    .font(MeshDropFont.display(20, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Spacer()
            }
            Text("scanning · \(Mock.me.ip)/24 · LAN ONLY")
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                .tracking(0.5)
                .padding(.top, 2)
        }
    }

    private var radarBlock: some View {
        HStack {
            Spacer()
            Radar(devices: Mock.devices.filter(\.isOnline), mode: .sweep,
                  selectedDevice: state.selectedDevice, diameter: 300)
            Spacer()
        }
    }

    private var deviceListBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsciiDivider("DEVICES · 设备 · \(Mock.devices.count)")
            ForEach(Mock.devices) { d in
                DeviceCard(d, selected: state.selectedDeviceID == d.id)
                    .onTapGesture {
                        state.selectedDeviceID = d.id
                        state.phoneTab = .chats
                    }
                    .contextMenu {
                        Button("发送…") { state.showSendSheet = true }
                        Button("查看资料") {}
                        Button("静音") {}
                        Divider()
                        Button("取消信任", role: .destructive) {}
                    }
            }
        }
    }

    private var quickStripBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("QUICK SEND · 快捷发送")
            HStack(spacing: 10) {
                quickItem("文本",  "text.alignleft",  variant: .ink)
                quickItem("剪贴板", "doc.on.clipboard", variant: .ghost)
                quickItem("照片",   "photo.on.rectangle", variant: .ghost)
                quickItem("文件",   "folder",         variant: .ghost)
            }
        }
    }

    @ViewBuilder
    private func quickItem(_ label: String, _ symbol: String, variant: IconBtn.Variant) -> some View {
        Button { state.showSendSheet = true } label: {
            VStack(spacing: 6) {
                IconBtn(symbol, size: 44, variant: variant, shape: .square)
                Text(label)
                    .font(MeshDropFont.body(11, weight: .medium))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Chip("E2E", tone: .outline, mono: true, uppercased: true)
            Chip("LAN ONLY", tone: .outline, mono: true, uppercased: true)
            Chip("可见", tone: .lime, mono: true, uppercased: true, icon: "eye.fill")
            Spacer()
            Text(Mock.me.fingerprint.prefix(11))
                .font(MeshDropFont.mono(10))
                .tracking(0.5)
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
        }
    }
}
