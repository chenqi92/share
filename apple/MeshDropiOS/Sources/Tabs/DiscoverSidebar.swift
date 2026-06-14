import SwiftUI
import MeshDropKit

/// iPad NavigationSplitView 左栏 — 顶部 brand + 雷达 + 设备列表 + 节区切换。
struct DiscoverSidebar: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
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
        Button { section = target } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                Text(label).font(MeshDropFont.body(13.5, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(section == target
                             ? MeshDropColor.ink
                             : (scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(section == target
                          ? MeshDropColor.lime
                          : (scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
