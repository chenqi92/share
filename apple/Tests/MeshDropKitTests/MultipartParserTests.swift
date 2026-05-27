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
}
