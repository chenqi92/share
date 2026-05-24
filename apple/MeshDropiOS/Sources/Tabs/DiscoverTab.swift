import SwiftUI
import MeshDropKit

struct DiscoverTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

    private var devices: [MockDevice] { engine.displayDevices }
    private var me: MockMe { engine.displaySelf }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    if let err = engine.lastError {
                        errorBanner(err)
                    }
                    heroBlock
                    radarBlock
                    deviceListBlock
                    quickStripBlock
                    AsciiDivider("LAN · \(me.ip)/24 · \(engine.isStarting ? "SCANNING" : "LIVE")")
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
            Chip(engine.isStarting ? "SCAN" : "LIVE",
                 tone: engine.isStarting ? .flame : .lime,
                 mono: true, uppercased: true, icon: "circle.fill")
            IconBtn("line.3.horizontal", size: 32, variant: .ghost) {
                state.showSettings = true
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MeshDropColor.flame)
            Text("网络出错 — \(msg)")
                .font(MeshDropFont.mono(11))
                .lineLimit(2)
            Spacer()
            Button("×") { engine.clearLastError() }
                .font(MeshDropFont.mono(14, weight: .bold))
                .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeshDropColor.flame.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(MeshDropColor.flame.opacity(0.6), lineWidth: 0.5)
        )
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("附近")
                    .font(MeshDropFont.display(34, weight: .bold))
                Text("\(devices.filter(\.isOnline).count) 台")
                    .font(MeshDropFont.mono(14, weight: .semibold))
                    .foregroundStyle(MeshDropColor.flame)
            }
            HStack(spacing: 6) {
                Text("Nearby devices.")
                    .font(MeshDropFont.display(20, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Spacer()
            }
            Text(engine.isStarting ? "scanning · \(me.ip)/24 · LAN ONLY" : "ready · \(me.ip)/24 · LAN ONLY")
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                .tracking(0.5)
                .padding(.top, 2)
        }
    }

    private var radarBlock: some View {
        HStack {
            Spacer()
            Radar(devices: devices.filter(\.isOnline), mode: .sweep,
                  selectedDevice: state.selectedDeviceDisplay(engine: engine),
                  meIP: me.ip, diameter: 300)
            Spacer()
        }
    }

    @ViewBuilder
    private var deviceListBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsciiDivider("DEVICES · 设备 · \(devices.count)")
            if devices.isEmpty {
                emptyDeviceCard
            } else {
                ForEach(devices) { d in
                    DeviceCard(d, selected: state.selectedDeviceID == d.id)
                        .onTapGesture {
                            state.selectedDeviceID = d.id
                            state.phoneTab = .chats
                        }
                        .contextMenu {
                            Button("发送…") {
                                state.selectedDeviceID = d.id
                                state.showSendSheet = true
                            }
                            Button("查看资料") {}
                            Button("静音") {}
                            Divider()
                            Button("取消信任", role: .destructive) {
                                if let real = engine.realDevice(for: d.id) {
                                    engine.revokeTrust(fingerprint: real.fingerprint)
                                }
                            }
                        }
                }
            }
        }
    }

    private var emptyDeviceCard: some View {
        VStack(spacing: 8) {
            Text("附近没有 MeshDrop 设备")
                .font(MeshDropFont.body(13.5, weight: .semibold))
            Text("让朋友也打开试试 · 同一 Wi-Fi 自动发现")
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
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
            Chip(engine.isStarting ? "扫描中" : "可见",
                 tone: .lime,
                 mono: true, uppercased: true,
                 icon: engine.isStarting ? "circle.dotted" : "eye.fill")
            Spacer()
            Text(me.fingerprint.prefix(11))
                .font(MeshDropFont.mono(10))
                .tracking(0.5)
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
        }
    }
}
