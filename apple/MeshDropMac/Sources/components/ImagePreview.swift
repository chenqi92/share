import AppKit
import SwiftUI

struct ImagePreview: View {
    let url: URL?
    let base64: String?
    var cornerRadius: CGFloat = 12

    private var image: NSImage? {
        if let base64,
           let data = Data(base64Encoded: base64),
           let image = NSImage(data: data) {
            return image
        }
        if let url {
            return NSImage(contentsOf: url)
        }
        return nil
    }

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
    }
}
