import SwiftUI
import MeshDropKit

/// 底部 mono 状态条。
struct StatusBar: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var engine = ShareEngine.shared

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(state.isScanning ? MeshDropColor.flame : MeshDropColor.limeDeep)
                .frame(width: 6, height: 6)
            Text(state.isScanning ? "\(String(localized: "status.scanning")) · \(engine.routeLabel)" : engine.routeLabel)
                .meshTag()
                .foregroundStyle(state.isScanning ? MeshDropColor.flame : MeshDropColor.limeDeep)
            Divider().frame(height: 12)
            Text("\(state.localIPSummary)")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
            Spacer()
            if let err = state.lastError {
                Text("ERR · \(err)")
                    .font(MeshDropFont.mono(size: 10, weight: .semibold))
                    .foregroundStyle(MeshDropColor.error)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .onTapGesture { state.clearError() }
                Divider().frame(height: 12)
            }
            Text("FP \(state.localFingerprintShort)")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Rectangle()
                .fill(MeshDropColor.cardBg)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(MeshDropColor.divider),
                    alignment: .top
                )
        )
    }
}
