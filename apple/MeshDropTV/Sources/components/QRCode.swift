import SwiftUI
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

/// 用 CIQRCodeGenerator 生成 mock 配对二维码。
struct MeshQRCode: View {
    var content: String
    var size: CGFloat = 320

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MeshDropColor.dpaper)
                .frame(width: size + 32, height: size + 32)

            if let image = makeImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Rectangle()
                    .fill(MeshDropColor.dink2)
                    .frame(width: size, height: size)
                    .overlay(Text("QR").font(MeshDropFont.monoL()).foregroundStyle(MeshDropColor.ink))
            }
        }
    }

    private func makeImage() -> UIImage? {
        #if canImport(CoreImage)
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
        #else
        return nil
        #endif
    }
}
