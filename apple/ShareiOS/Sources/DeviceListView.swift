import SwiftUI
import ShareKit

struct DeviceListView: View {
    @EnvironmentObject var engine: ShareEngine
    @State private var sendingTo: Device?

    var body: some View {
        ScrollView {
            if engine.devices.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(engine.devices) { device in
                        Button {
                            sendingTo = device
                        } label: {
                            DeviceRow(device: device)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
            }
        }
        .sheet(item: $sendingTo) { device in
            SendTextSheet(device: device)
                .environmentObject(engine)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("正在搜索附近设备…")
                .font(.headline)
            Text("确保对方设备在同一 Wi-Fi 下并已启动 MeshDrop")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 64)
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: device.os))
                .font(.title2)
                .frame(width: 36, height: 36)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(device.os.rawValue)
                    if let model = device.model { Text("· \(model)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
