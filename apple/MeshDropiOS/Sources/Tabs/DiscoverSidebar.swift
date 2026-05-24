import SwiftUI

/// iPad NavigationSplitView 左栏 — 顶部 brand + 雷达 + 设备列表 + 节区切换。
struct DiscoverSidebar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    @Binding var section: PadRoot.PadSection

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    radarHeader
                    radar
                    devices
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
            Chip("LIVE \(Mock.devices.filter(\.isOnline).count)", tone: .lime,
                 mono: true, uppercased: true, icon: "circle.fill")
        }
    }

    private var radarHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("附近 · Nearby")
                .font(MeshDropFont.display(22, weight: .bold))
            Text("scanning · \(Mock.me.ip)/24")
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
    }

    private var radar: some View {
        Radar(devices: Mock.devices.filter(\.isOnline), mode: .sweep,
              selectedDevice: state.selectedDevice, diameter: 280)
            .frame(maxWidth: .infinity)
    }

    private var devices: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("DEVICES · \(Mock.devices.count)")
            ForEach(Mock.devices) { d in
                DeviceCard(d, selected: state.selectedDeviceID == d.id, dense: true)
                    .onTapGesture {
                        state.selectedDeviceID = d.id
                        section = .chat
                    }
            }
        }
    }

    private var sectionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsciiDivider("SECTIONS")
            sectionRow("聊天", "message", .chat)
            sectionRow("传输", "arrow.up.arrow.down", .transfers)
            sectionRow("历史", "clock.arrow.circlepath", .history)
            sectionRow("信任", "checkmark.shield", .trust)
            sectionRow("设置", "gearshape", .settings)
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
