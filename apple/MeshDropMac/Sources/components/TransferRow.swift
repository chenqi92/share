import AppKit
import SwiftUI

/// 文件 icon (38×46) + name + size + 状态行 + （进行中时）进度条 + speed + ETA。
/// `onCancel` 闭包传入时，且 state 是 sending / receiving，状态 chip 右侧渲染
/// 取消按钮；调用方负责发 FILE_CANCEL（见 AppState.cancelTransfer）。
/// `onRetry` 闭包传入时，且 state 是 failed，状态 chip 右侧渲染重试按钮，
/// 调用方负责调用 AppState.retryTransfer。
struct TransferRow: View {
    let item: MockTransfer
    var onCancel: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    /// 已完成接收项的本地保存路径 —— 传入后右侧渲染 Reveal / Open 按钮。
    var savedURL: URL? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FileIcon(ext: item.ext, color: stateColor)
                .frame(width: 38, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(MeshDropFont.body(size: 13.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.size)
                        .font(MeshDropFont.mono(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer(minLength: 0)
                    Chip(text: stateText, tone: stateTone, mono: true)
                    if let onCancel, item.state == .sending || item.state == .receiving {
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(MeshDropColor.flame)
                        }
                        .buttonStyle(.plain)
                        .help("取消传输 · Cancel")
                    }
                    if let onRetry, item.state == .failed {
                        Button(action: onRetry) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("RETRY")
                                    .font(MeshDropFont.mono(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(MeshDropColor.flame)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(MeshDropColor.flame.opacity(0.4), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("重试发送 · Retry")
                    }
                    if let savedURL, item.state == .done, item.to == "我" {
                        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([savedURL]) }) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("在 Finder 中显示 · Reveal in Finder")
                        Button(action: { NSWorkspace.shared.open(savedURL) }) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("打开 · Open")
                    }
                }

                HStack(spacing: 8) {
                    Text(arrow)
                        .font(MeshDropFont.mono(size: 11, weight: .bold))
                        .foregroundStyle(stateColor)
                    Text("\(item.from) → \(item.to)")
                        .font(MeshDropFont.mono(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                    if let speed = item.speed {
                        Text("· \(speed)")
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                    if let eta = item.eta {
                        Text("· ETA \(eta)")
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                }

                if item.state == .sending || item.state == .receiving {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(MeshDropColor.divider)
                            .frame(height: 4)
                        GeometryReader { geo in
                            Capsule()
                                .fill(stateColor)
                                .frame(width: max(4, geo.size.width * CGFloat(item.progress) / 100),
                                       height: 4)
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeshDropColor.cardBg)
                .shadow(color: MeshDropColor.ink06, radius: 1, x: 0, y: 1)
        )
    }

    private var stateColor: Color {
        switch item.state {
        case .sending:   return MeshDropColor.flame
        case .receiving: return MeshDropColor.sky
        case .done:      return MeshDropColor.limeDeep
        case .failed:    return MeshDropColor.error
        case .queued:    return MeshDropColor.ink45
        }
    }
    private var stateText: String {
        switch item.state {
        case .sending:   return "SENDING · \(item.progress)%"
        case .receiving: return "RECV · \(item.progress)%"
        case .done:      return "DONE"
        case .failed:    return "FAILED"
        case .queued:    return "QUEUED"
        }
    }
    private var stateTone: ChipTone {
        switch item.state {
        case .sending:   return .flame
        case .receiving: return .outline
        case .done:      return .lime
        case .failed:    return .flame
        case .queued:    return .outline
        }
    }
    private var arrow: String {
        switch item.state {
        case .sending:   return "↑"
        case .receiving: return "↓"
        case .done:      return "✓"
        case .failed:    return "×"
        case .queued:    return "·"
        }
    }
}
