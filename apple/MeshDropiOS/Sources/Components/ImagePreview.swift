import SwiftUI
import UIKit
import MeshDropKit

struct ImagePreview: View {
    let url: URL?
    let base64: String?
    var cornerRadius: CGFloat = 14
    var isVideo = false
    @State private var thumbnail: UIImage?

    @State private var loadedSource: String?
    private var sourceID: String { "\(url?.absoluteString ?? "")|\(base64 ?? "")|\(isVideo)" }

    var body: some View {
        GeometryReader { bounds in
          ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: isVideo ? "video" : "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.secondary)
            }
            if isVideo, thumbnail != nil {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
          }
          .frame(width: bounds.size.width, height: bounds.size.height)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .task(id: sourceID) {
            if loadedSource != sourceID {
                thumbnail = nil
                loadedSource = sourceID
            }
            if let image = await MediaThumbnail.image(url: url, base64: base64, isVideo: isVideo), !Task.isCancelled {
                thumbnail = UIImage(cgImage: image)
            }
        }
    }
}
