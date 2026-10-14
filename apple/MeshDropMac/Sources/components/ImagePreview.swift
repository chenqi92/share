import AppKit
import SwiftUI
import MeshDropKit

struct ImagePreview: View {
    let url: URL?
    let base64: String?
    var cornerRadius: CGFloat = 12

    @State private var image: NSImage?

    @State private var loadedSource: String?
    private var sourceID: String { "\(url?.absoluteString ?? "")|\(base64 ?? "")" }

    var body: some View {
        GeometryReader { bounds in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .task(id: sourceID) {
            if loadedSource != sourceID {
                image = nil
                loadedSource = sourceID
            }
            if let thumbnail = await MediaThumbnail.image(url: url, base64: base64), !Task.isCancelled {
                image = NSImage(cgImage: thumbnail, size: .zero)
            }
        }
    }
}
