import XCTest
@testable import MeshDropKit

final class GatewayStaticFilesTests: XCTestCase {
    func testAssetsAndIndexQueriesHaveBrowserContentTypes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("assets"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (path, type) in [("index.html", "text/html; charset=utf-8"), ("assets/app.js", "text/javascript; charset=utf-8"), ("assets/app.css", "text/css; charset=utf-8"), ("font.woff2", "font/woff2")] {
            try Data(path.utf8).write(to: root.appendingPathComponent(path))
            let resource = try XCTUnwrap(GatewayStaticFiles.load(path: "/\(path)?v=1", root: root))
            XCTAssertEqual(resource.contentType, type)
            XCTAssertEqual(resource.body, Data(path.utf8))
        }
        XCTAssertEqual(GatewayStaticFiles.load(path: "/?page=pairing", root: root)?.body, Data("index.html".utf8))
    }

    func testMissingFilesAndTraversalCannotReadOutsideStaticRoot() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = temp.appendingPathComponent("web")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let secret = temp.appendingPathComponent("secret.json")
        try Data("secret".utf8).write(to: secret)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.json"), withDestinationURL: secret)
        for path in ["/../secret.json", "/%2e%2e/secret.json", "/%2e%2e%2fsecret.json", "/..%5csecret.json", "/link.json", "/missing.js", "/%00.json"] {
            XCTAssertNil(GatewayStaticFiles.load(path: path, root: root), path)
        }
    }
}
