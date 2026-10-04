import SwiftUI
import UIKit
import ImageIO
import AVFoundation
import MeshDropKit

struct ImagePreview: View {
    let url: URL?
    let base64: String?
    var cornerRadius: CGFloat = 14
    var isVideo = false
    @State private var thumbnail: UIImage?

    var body: some View {
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
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: "\(url?.absoluteString ?? "")|\(base64 ?? "")|\(isVideo)") {
            thumbnail = nil
            let file = LocalFileContent.readableURL(url)
            if isVideo, let file {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 660, height: 660)
                if let frame = try? await generator.image(at: .zero), !Task.isCancelled {
                    thumbnail = UIImage(cgImage: frame.image)
                }
            } else {
                let task = Task.detached(priority: .userInitiated) {
                    let source: CGImageSource?
                    if let base64, let data = Data(base64Encoded: base64) {
                        source = CGImageSourceCreateWithData(data as CFData, nil)
                    } else if let file {
                        source = CGImageSourceCreateWithURL(file as CFURL, nil)
                    } else { source = nil }
                    guard let source else { return nil as UIImage? }
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 660
                    ]
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                        .map { UIImage(cgImage: $0) }
                }
                let image = await task.value
                if !Task.isCancelled { thumbnail = image }
            }
        }
    }
}
