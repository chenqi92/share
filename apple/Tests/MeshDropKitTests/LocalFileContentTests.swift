import XCTest
@testable import MeshDropKit

final class LocalFileContentTests: XCTestCase {
    func testOnlyExistingReadableFilesCanBePreviewed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("picture.png")
        try Data([1, 2, 3]).write(to: file)
        XCTAssertEqual(LocalFileContent.readableURL(file), file)
        XCTAssertNil(LocalFileContent.readableURL(directory))
        XCTAssertNil(LocalFileContent.readableURL(URL(string: "https://example.com/picture.png")))
        try FileManager.default.removeItem(at: file)
        XCTAssertNil(LocalFileContent.readableURL(file))
        XCTAssertNil(LocalFileContent.readableURL(nil))
    }

    func testVideoTypeRecognition() {
        XCTAssertTrue(LocalFileContent.isVideo(name: "旅行.MP4"))
        XCTAssertTrue(LocalFileContent.isVideo(name: "clip.mov"))
        XCTAssertFalse(LocalFileContent.isVideo(name: "movie.mp4.txt"))
    }

    func testMarkdownFilesPreserveSourceAndFallBackForUnsupportedContent() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".MD")
        defer { try? FileManager.default.removeItem(at: url) }
        let source = "# 中文\n\n```swift\nprint(1)\n```\n"
        try Data(source.utf8).write(to: url)
        XCTAssertEqual(LocalFileContent.markdownText(url), source)
        try Data([0xFF, 0xFE]).write(to: url)
        XCTAssertNil(LocalFileContent.markdownText(url))
        try Data(repeating: 65, count: 512_001).write(to: url)
        XCTAssertNil(LocalFileContent.markdownText(url))
    }
}
