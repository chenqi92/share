import SwiftUI
import ShareKit

struct DeviceListView: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.horizontalSizeClass) var hSize
    @State private var sendingTo: Device?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("附近设备")
                    .font(.title3.weight(.semibold))
                if !engine.devices.isEmpty {
                    Text("\(engine.devices.count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, sidePadding)

            if engine.devices.isEmpty {
                emptyState
            } else if hSize == .regular {
                // iPad：双/多列自适应卡片
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(engine.devices) { device in
                        DeviceCardLarge(device: device)
                            .onTapGesture { sendingTo = device }
                    }
                }
                .padding(.horizontal, sidePadding)
            } else {
                // iPhone：单列横向行
                LazyVStack(spacing: 12) {
                    ForEach(engine.devices) { device in
                        DeviceRow(device: device)
                            .onTapGesture { sendingTo = device }
                    }
                }
                .padding(.horizontal, sidePadding)
            }
        }
        .sheet(item: $sendingTo) { device in
            SendSheet(device: device).environmentObject(engine)
        }
    }

    private var sidePadding: CGFloat { hSize == .regular ? 32 : 16 }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
            Text("正在搜索附近设备…")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text("确保对方设备在同一 Wi-Fi 下并已启动 MeshDrop")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

// MARK: - 两种 device 视图

/// iPad / 大屏专用大卡片。
struct DeviceCardLarge: View {
    let device: Device

    var body: some View {
        VStack(spacing: 12) {
            DeviceIcon(os: device.os, size: 64)

            VStack(spacing: 3) {
                Text(device.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(deviceSubtitle(device))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "paperplane.fill").font(.system(size: 11))
                Text("发送").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// iPhone / 紧凑屏专用横排行。
struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 14) {
            DeviceIcon(os: device.os, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(deviceSubtitle(device))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

// MARK: - 共享组件

struct DeviceIcon: View {
    let os: DeviceOS
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(
                    colors: gradientColors(for: os),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Image(systemName: iconName(for: os))
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(.white)
        }
        .shadow(color: gradientColors(for: os).first?.opacity(0.25) ?? .clear,
                radius: size * 0.13, y: 3)
    }
}

func gradientColors(for os: DeviceOS) -> [Color] {
    switch os {
    case .ios:     return [.blue, .indigo]
    case .android: return [.green, .mint]
    case .macos:   return [.purple, .pink]
    case .windows: return [.cyan, .blue]
    case .linux:   return [.orange, .red]
    }
}

func iconName(for os: DeviceOS) -> String {
    switch os {
    case .ios:     return "iphone"
    case .android: return "candybarphone"
    case .macos:   return "macbook"
    case .windows: return "pc"
    case .linux:   return "desktopcomputer"
    }
}

func deviceSubtitle(_ device: Device) -> String {
    let osName: String = {
        switch device.os {
        case .ios:     return "iOS"
        case .android: return "Android"
        case .macos:   return "macOS"
        case .windows: return "Windows"
        case .linux:   return "Linux"
        }
    }()
    if let m = device.model, !m.isEmpty { return "\(osName) · \(m)" }
    return osName
}
