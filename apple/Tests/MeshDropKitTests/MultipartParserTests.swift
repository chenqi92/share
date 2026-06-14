import XCTest
@testable import MeshDropKit

final class MultipartParserTests: XCTestCase {

    func testBoundaryFromContentType() {
        XCTAssertEqual(
            MultipartParser.boundary(fromContentType: "multipart/form-data; boundary=----abc"),
            "----abc"
        )
        XCTAssertEqual(
            MultipartParser.boundary(fromContentType: "multipart/form-data; boundary=\"q ed\"; charset=utf-8"),
            "q ed"
        )
        XCTAssertNil(
            MultipartParser.boundary(fromContentType: "application/json")
        )
    }

    func testFirstFilePartExtractsFileBody() throws {
        let boundary = "----WebKitFormBoundaryABC"
        let body = [
            "--\(boundary)\r\n",
            "Content-Disposition: form-data; name=\"file\"; filename=\"hello.txt\"\r\n",
            "Content-Type: text/plain\r\n",
            "\r\n",
            "hello world\r\n",
            "--\(boundary)--\r\n",
        ].joined()
        let part = try MultipartParser.firstFilePart(body: Data(body.utf8), boundary: boundary)
        XCTAssertEqual(part.name, "file")
        XCTAssertEqual(part.filename, "hello.txt")
        XCTAssertEqual(part.contentType, "text/plain")
        XCTAssertEqual(part.body, Data("hello world".utf8))
    }

    func testSkipsNonFileFieldAndFindsFile() throws {
        let boundary = "X"
        let body = [
            "--X\r\n",
            "Content-Disposition: form-data; name=\"note\"\r\n",
            "\r\n",
            "just text\r\n",
            "--X\r\n",
            "Content-Disposition: form-data; name=\"upload\"; filename=\"a.bin\"\r\n",
            "Content-Type: application/octet-stream\r\n",
            "\r\n",
            "binary-data",
            "\r\n--X--\r\n",
        ].joined()
        let part = try MultipartParser.firstFilePart(body: Data(body.utf8), boundary: boundary)
        XCTAssertEqual(part.name, "upload")
        XCTAssertEqual(part.filename, "a.bin")
        XCTAssertEqual(part.body, Data("binary-data".utf8))
    }

    func testMalformedThrows() {
        let body = Data("not-a-multipart".utf8)
        XCTAssertThrowsError(try MultipartParser.firstFilePart(body: body, boundary: "X"))
    }

    func testSanitizeFilenameStripsTraversal() {
        // 目录穿越尝试只保留最后一段，剥掉分隔符与 ..
        XCTAssertEqual(MultipartParser.sanitizeFilename("../../etc/passwd"), "passwd")
        XCTAssertEqual(MultipartParser.sanitizeFilename("..\\..\\windows\\hosts"), "hosts")
        XCTAssertEqual(MultipartParser.sanitizeFilename("/abs/path/file.bin"), "file.bin")
        XCTAssertEqual(MultipartParser.sanitizeFilename("plain.txt"), "plain.txt")
        // 纯 .. / . / 空 → 随机名兜底
        XCTAssertTrue(MultipartParser.sanitizeFilename("..").hasPrefix("upload-"))
        XCTAssertTrue(MultipartParser.sanitizeFilename("").hasPrefix("upload-"))
    }

    func testParsedFilenameIsSanitized() throws {
        let boundary = "X"
        let body = [
            "--X\r\n",
            "Content-Disposition: form-data; name=\"file\"; filename=\"../../evil.sh\"\r\n",
            "Content-Type: application/octet-stream\r\n",
            "\r\n",
            "payload",
            "\r\n--X--\r\n",
        ].joined()
        let part = try MultipartParser.firstFilePart(body: Data(body.utf8), boundary: boundary)
        XCTAssertEqual(part.filename, "evil.sh")
    }
}
