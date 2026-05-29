import SwiftUI

/// 下载管理器行：文件 icon + name + size + 状态行 + 进度条 + speed + ETA。
/// 传入 `onCancel` 且 state 为 transferring 时，状态行右侧渲染取消图标，
/// 调用方负责发 FILE_CANCEL（见 ShareEngine.cancelTransfer）。
/// 传入 `onRetry` 且 state 为 failed 时，状态行右侧渲染重试按钮，
/// 调用方负责调用 ShareEngine.retryTransfer。
/// 传入 `onOpen` 且 state 为 done 时，状态行右侧渲染打开按钮，
/// 调用方负责用 QuickLook 预览已接收文件。
public struct TransferRow: View {
    let item: MockTransfer
    var onCancel: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    @Environment(\.colorScheme) private var scheme

    public init(_ item: MockTransfer, onCancel: (() -> Void)? = nil, onRetry: (() -> Void)? = nil, onOpen: (() -> Void)? = nil) {
        self.item = item
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FileTile(ext: item.ext, size: 38)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name)
                        .font(MeshDropFont.body(14, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.size)
                        .font(MeshDropFont.mono(11))
                        .foregroundStyle(muted)
                }

                HStack(spacing: 6) {
                    directionIcon
                    Text(directionText)
                        .font(MeshDropFont.mono(11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(stateColor)
                    if let speed = item.speed {
                        Text("· \(speed)")
                            .font(MeshDropFont.mono(11))
                            .foregroundStyle(muted)
                    }
                    if let eta = item.eta, item.state == .transferring {
                        Text("· ETA \(eta)")
                            .font(MeshDropFont.mono(11))
                            .foregroundStyle(muted)
                    }
                    Spacer(minLength: 4)
                    if item.state == .transferring {
                        Text("\(item.progress)%")
                            .font(MeshDropFont.mono(11, weight: .semibold))
                            .foregroundStyle(stateColor)
                            .monospacedDigit()
                        if let onCancel {
                            Button(action: onCancel) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(MeshDropColor.flame)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("取消传输")
                        }
                    }
                    if item.state == .failed, let onRetry {
                        Button(action: onRetry) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("RETRY")
                                    .font(MeshDropFont.mono(10, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(MeshDropColor.flame)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(MeshDropColor.flame.opacity(0.4), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重试发送")
                    }
                    if item.state == .done, let onOpen {
                        Spacer(minLength: 4)
                        Button(action: onOpen) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("OPEN")
                                    .font(MeshDropFont.mono(10, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(MeshDropColor.limeDeep)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(MeshDropColor.limeDeep.opacity(0.5), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("打开文件")
                    }
                }

                if item.state == .transferring || item.state == .done {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(scheme == .dark ? Color.white.opacity(0.08) : MeshDropColor.ink12)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stateColor)
                                .frame(width: max(2, geo.size.width * CGFloat(item.progress) / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var stateColor: Color {
        switch item.state {
        case .done:         return MeshDropColor.limeDeep
        case .transferring: return item.direction == .outgoing ? MeshDropColor.flame : MeshDropColor.sky
        case .queued:       return scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45
        case .failed:       return MeshDropColor.error
        }
    }

    private var directionText: String {
        switch item.state {
        case .done:         return "完成 · 给 \(item.to)"
        case .transferring: return item.direction == .outgoing
            ? "发送中 · 给 \(item.to)" : "接收中 · 来自 \(item.from)"
        case .queued:       return "排队 · 给 \(item.to)"
        case .failed:       return item.failReason.map { "失败 · \($0)" } ?? "失败"
        }
    }

    @ViewBuilder private var directionIcon: some View {
        switch item.state {
        case .done:
            Text("✓").font(MeshDropFont.mono(11, weight: .bold)).foregroundStyle(stateColor)
        case .transferring:
            Text(item.direction == .outgoing ? "↑" : "↓").font(MeshDropFont.mono(11, weight: .bold)).foregroundStyle(stateColor)
        case .queued:
            Text("·").font(MeshDropFont.mono(11, weight: .bold)).foregroundStyle(stateColor)
        case .failed:
            Text("×").font(MeshDropFont.mono(11, weight: .bold)).foregroundStyle(stateColor)
        }
    }

    private var muted: Color { scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45 }
}
