import SwiftUI
import UIKit

struct ImagePreview: View {
    let url: URL?
    let base64: String?
    var cornerRadius: CGFloat = 14

    private var image: UIImage? {
        if let base64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        if let url {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Photo(hue: 210)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
