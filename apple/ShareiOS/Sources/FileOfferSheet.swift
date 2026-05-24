import SwiftUI
import ShareKit

struct FileOfferSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let offer: PendingFileOffer

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(offer.peer.name) 想发送文件")
                            .font(.headline)
                        Text("接受后将保存到 App 的 MeshDrop 文件夹")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
                .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    Button {
                        engine.respondToFileOffer(offer.id, accept: true)
                        dismiss()
                    } label: {
                        Text("接受").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        engine.respondToFileOffer(offer.id, accept: false)
                        dismiss()
                    } label: {
                        Text("拒绝").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
            .padding(20)
            .navigationTitle("收到文件")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
