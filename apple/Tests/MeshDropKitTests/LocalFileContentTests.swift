import XCTest
@testable import MeshDropKit

final class LocalFileContentTests: XCTestCase {
    func testMediaPathsFollowAnUpdatedIOSContainer() {
        let oldContainer = "/private/var/mobile/Containers/Data/Application/\(UUID().uuidString)"
        let current = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/\(UUID().uuidString)")
        for relative in ["Documents/MeshDrop/Mac/旅行.heic", "Library/Application Support/MeshDrop/Attachments/clip.mov", "tmp/IMG.webp"] {
            let old = URL(fileURLWithPath: oldContainer).appendingPathComponent(relative)
            XCTAssertEqual(LocalFileContent.rebasedURL(old, container: current), current.appendingPathComponent(relative))
        }
        for path in ["/Users/me/Downloads/photo.jpg", "/var/mobile/Containers/Shared/AppGroup/\(UUID().uuidString)/photo.jpg", oldContainer + "/../../outside.jpg"] {
            let outside = URL(fileURLWithPath: path)
            XCTAssertEqual(LocalFileContent.rebasedURL(outside, container: current), outside)
        }
    }

    func testRetainedPhotoMovesOutOfTemporaryStorage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let temporary = root.appendingPathComponent("tmp")
        let attachments = root.appendingPathComponent("Attachments")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = temporary.appendingPathComponent("IMG.webp")
        let bytes = Data([1, 2, 3, 4])
        try bytes.write(to: source)
        let id = UUID()
        let retained = try LocalFileContent.retainTemporaryAttachment(source, id: id,
            temporaryDirectory: temporary, attachmentsDirectory: attachments)
        XCTAssertEqual(retained.lastPathComponent, source.lastPathComponent)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: retained), bytes)
        XCTAssertEqual(try LocalFileContent.retainTemporaryAttachment(source, id: id,
            temporaryDirectory: temporary, attachmentsDirectory: attachments), retained)
        XCTAssertEqual(try LocalFileContent.retainTemporaryAttachment(retained, id: UUID(),
            temporaryDirectory: temporary, attachmentsDirectory: attachments), retained)
    }

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
