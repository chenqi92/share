import Foundation
import ImageIO
import AVFoundation

public enum MediaThumbnail {
    private final class Entry: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 80
        cache.totalCostLimit = 40 * 1024 * 1024
        return cache
    }()

    public static func image(url: URL?, base64: String?, isVideo: Bool = false) async -> CGImage? {
        let file = LocalFileContent.readableURL(url)
        // URL resource values can retain stale metadata after a file is replaced.
        let metadata = file.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
        let modified = (metadata?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (metadata?[.size] as? NSNumber)?.uint64Value ?? 0
        let key = "\(file?.absoluteString ?? "")|\(modified)|\(size)|\(base64 ?? "")|\(isVideo)" as NSString
        if let cached = cache.object(forKey: key) { return cached.image }
        let image: CGImage?
        if isVideo, let file {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 660, height: 660)
            image = try? await generator.image(at: .zero).image
        } else {
            image = await Task.detached(priority: .userInitiated) {
                let source: CGImageSource?
                if let file {
                    source = CGImageSourceCreateWithURL(file as CFURL, nil)
                } else if let base64, let data = Data(base64Encoded: base64) {
                    source = CGImageSourceCreateWithData(data as CFData, nil)
                } else { source = nil }
                guard let source else { return nil as CGImage? }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 660,
                    kCGImageSourceShouldCacheImmediately: true,
                ]
                return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            }.value
        }
        guard !Task.isCancelled, let image else { return nil }
        cache.setObject(Entry(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}
