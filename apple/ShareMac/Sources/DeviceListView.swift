import SwiftUI
import ShareKit

struct DeviceListView: View {
    @EnvironmentObject var engine: ShareEngine
    @State private var sendingTo: Device?

    var body: some View {
        Group {
            if engine.devices.isEmpty {
                ContentUnavailableView(
                    "正在搜索附近设备…",
                    systemImage: "magnifyingglass",
                    description: Text("确保对方设备在同一 Wi-Fi 或局域网下，并已启动 MeshDrop。")
                )
            } else {
                List(engine.devices) { device in
                    Button {
                        sendingTo = device
                    } label: {
                        DeviceRow(device: device)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $sendingTo) { device in
            SendTextSheet(device: device)
                .environmentObject(engine)
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: device.os))
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(device.os.rawValue)
                    if let model = device.model { Text("· \(model)") }
                    Text("· :\(device.port)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func icon(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "iphone"
        case .android: return "candybarphone"
        case .macos:   return "laptopcomputer"
        case .windows: return "desktopcomputer"
        case .linux:   return "pc"
        }
    }
}
