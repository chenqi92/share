import SwiftUI
import ShareKit

/// 设备区：标题 + 自适应多列卡片 grid / 空状态。
struct DeviceArea: View {
    @EnvironmentObject var engine: ShareEngine
    @State private var sendingTo: Device?
    @State private var hoveredID: String?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)]

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

            if engine.devices.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(engine.devices) { device in
                        DeviceCard(device: device, isHovered: hoveredID == device.id)
                            .onHover { hoveredID = $0 ? device.id : nil }
                            .onTapGesture { sendingTo = device }
                    }
                }
            }
        }
        .sheet(item: $sendingTo) { device in
            SendTextSheet(device: device).environmentObject(engine)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
            Text("正在搜索附近设备…")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text("确保对方设备在同一 Wi-Fi 或局域网下，并已启动 MeshDrop")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(.regularMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 单个设备卡片：渐变 OS 徽标 + 名称 + 副标题 + 发送提示。
/// hover 时阴影加深、轻微缩放，给出可点击反馈。
struct DeviceCard: View {
    let device: Device
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .clear, radius: 8, y: 4)

            VStack(spacing: 3) {
                Text(device.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 10))
                Text("发送")
                    .font(.system(size: 12, weight: .medium))
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.14 : 0.06),
                radius: isHovered ? 16 : 10, y: isHovered ? 6 : 3)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isHovered)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if let m = device.model, !m.isEmpty { return "\(osName) · \(m)" }
        return osName
    }

    private var osName: String {
        switch device.os {
        case .ios:     return "iOS"
        case .android: return "Android"
        case .macos:   return "macOS"
        case .windows: return "Windows"
        case .linux:   return "Linux"
        }
    }

    private var gradientColors: [Color] {
        switch device.os {
        case .ios:     return [.blue, .indigo]
        case .android: return [.green, .mint]
        case .macos:   return [.purple, .pink]
        case .windows: return [.cyan, .blue]
        case .linux:   return [.orange, .red]
        }
    }

    private var icon: String {
        switch device.os {
        case .ios:     return "iphone"
        case .android: return "candybarphone"
        case .macos:   return "macbook"
        case .windows: return "pc"
        case .linux:   return "desktopcomputer"
        }
    }
}
