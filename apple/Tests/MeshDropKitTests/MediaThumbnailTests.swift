import XCTest
import ImageIO
@testable import MeshDropKit

final class MediaThumbnailTests: XCTestCase {
    func testDownsamplesAndReusesDecodedImage() async throws {
        let data = try png(width: 2000, height: 1000)
        let first = await MediaThumbnail.image(url: nil, base64: data.base64EncodedString())
        let second = await MediaThumbnail.image(url: nil, base64: data.base64EncodedString())
        let image = try XCTUnwrap(first)
        XCTAssertEqual(image.width, 660)
        XCTAssertEqual(image.height, 330)
        XCTAssertTrue(image === second)
    }

    func testReplacedFileDoesNotReuseOldThumbnail() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("MeshDrop-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        try png(width: 80, height: 40).write(to: file)
        let first = await MediaThumbnail.image(url: file, base64: nil)
        try png(width: 40, height: 80).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: file.path)
        let second = await MediaThumbnail.image(url: file, base64: nil)
        XCTAssertEqual(first?.width, 80)
        XCTAssertEqual(second?.width, 40)
    }

    func testUnreadableContentHasNoThumbnail() async {
        let image = await MediaThumbnail.image(url: nil, base64: "not-an-image")
        XCTAssertNil(image)
    }

    private func png(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
