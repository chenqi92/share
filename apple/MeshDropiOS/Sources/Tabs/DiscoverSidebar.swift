import SwiftUI
import MeshDropKit

/// iPad NavigationSplitView 左栏 — 顶部 brand + 雷达 + 设备列表 + 节区切换。
struct DiscoverSidebar: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
    // 选中态填充与次文字色复用全局 token，保证与 DeviceCard / macOS Sidebar 一致
    @Environment(\.meshLimeWash) private var limeWash
    @Environment(\.meshMuted) private var muted
    @Binding var section: PadRoot.PadSection

    private var devices: [MockDevice] { engine.displayDevices }
    private var me: MockMe { engine.displaySelf }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    radarHeader
                    radar
                    devicesList
                    sectionList
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
        }
    }

    private var topBar: some View {
        HStack {
            MeshDropLockup(size: 20)
            Spacer()
            Chip("LIVE \(devices.filter(\.isOnline).count)", tone: .lime,
                 mono: true, uppercased: true, icon: "circle.fill")
        }
    }

    private var radarHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MD("discovery.sidebar.title"))
                .font(MeshDropFont.display(22, weight: .bold))
            Text(engine.isStarting ? "scanning · \(me.ip)/24" : "LAN · \(me.ip)/24")
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
    }

    private var radar: some View {
        Radar(devices: devices.filter(\.isOnline), mode: .sweep,
              selectedDevice: state.selectedDeviceDisplay(engine: engine),
              meIP: me.ip, diameter: 280)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var devicesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("DEVICES · \(devices.count)")
            if devices.isEmpty {
                Text(MD("discovery.sidebar.devices.empty"))
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(devices) { d in
                    DeviceCard(d, selected: state.selectedDeviceID == d.id, dense: true)
                        .onTapGesture {
                            state.selectedDeviceID = d.id
                            section = .chat
                        }
                }
            }
        }
    }

    private var sectionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsciiDivider("SECTIONS")
            sectionRow(MD("discovery.sidebar.section.chat"), "message", .chat)
            sectionRow(MD("discovery.sidebar.section.transfers"), "arrow.up.arrow.down", .transfers)
            sectionRow(MD("discovery.sidebar.section.history"), "clock.arrow.circlepath", .history)
            sectionRow(MD("discovery.sidebar.section.trust"), "checkmark.shield", .trust)
            sectionRow(MD("discovery.sidebar.section.settings"), "gearshape", .settings)
        }
    }

    @ViewBuilder
    private func sectionRow(_ label: String, _ symbol: String, _ target: PadRoot.PadSection) -> some View {
        let selected = section == target
        // 主文字色（选中用），随外观切换
        let textPrimary = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        Button { section = target } label: {
            HStack(spacing: 10) {
                // 字重也参与选中区分：选中加粗、未选中常规（对齐 macOS Sidebar.navItem）
                Image(systemName: symbol).font(.system(size: 13, weight: selected ? .semibold : .regular))
                Text(label).font(MeshDropFont.body(13.5, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            // 选中=主文字色，未选中=次文字色
            .foregroundStyle(selected ? textPrimary : muted)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    // 选中=lime@32%/16% wash，未选中=透明（不再全填卡片底）
                    .fill(selected ? limeWash : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    // 选中=1px lime 描边，未选中=透明（去掉常驻 hairline）
                    .strokeBorder(selected ? MeshDropColor.lime : Color.clear,
                                  lineWidth: selected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}
