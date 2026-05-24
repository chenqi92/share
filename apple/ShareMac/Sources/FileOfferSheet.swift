import SwiftUI
import ShareKit

/// 收到对方 FILE_OFFER 时弹出，让用户决定接受或拒绝。
struct FileOfferSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let offer: PendingFileOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(offer.peer.name) 想发送文件")
                        .font(.headline)
                    Text("接受后将保存到 MeshDrop 文件夹")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.fileName)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(offer.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack {
                Button("拒绝", role: .destructive) {
                    engine.respondToFileOffer(offer.id, accept: false)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("接受") {
                    engine.respondToFileOffer(offer.id, accept: true)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
