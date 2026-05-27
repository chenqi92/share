import Foundation

/// 极简 `multipart/form-data` 解析（RFC 7578）—— 用于 [WebGateway] 的
/// `POST /api/v1/upload`。只支持单文件字段；提取 `filename` 与 body。
///
/// 不支持：嵌套 multipart、quoted-printable / base64 编码、multi-part 文件。
public enum MultipartParser {

    public struct FilePart {
        public let name: String        // form field name (eg. "file")
        public let filename: String    // 客户端给出的文件名
        public let contentType: String
        public let body: Data
    }

    public enum ParseError: Error {
        case missingBoundary
        case malformed
    }

    /// 解析 Content-Type header 中的 boundary。
    /// 输入形如 `multipart/form-data; boundary=----WebKitFormBoundaryABC`。
    public static func boundary(fromContentType header: String) -> String? {
        let lower = header.lowercased()
        guard lower.hasPrefix("multipart/form-data") else { return nil }
        guard let range = header.range(of: "boundary=", options: .caseInsensitive) else { return nil }
        var rest = String(header[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("\"") {
            rest.removeFirst()
            if let endQuote = rest.firstIndex(of: "\"") {
                return String(rest[..<endQuote])
            }
            return rest
        }
        if let sep = rest.firstIndex(of: ";") {
            return String(rest[..<sep]).trimmingCharacters(in: .whitespaces)
        }
        return rest
    }

    /// 解析 body，返回第一个 file part。
    public static func firstFilePart(body: Data, boundary: String) throws -> FilePart {
        let delim = "--\(boundary)".data(using: .utf8)!
        let crlf = Data([0x0D, 0x0A])
        let dCRLF = Data([0x0D, 0x0A, 0x0D, 0x0A])

        // 找第一个 boundary
        guard let firstBoundary = body.range(of: delim) else {
            throw ParseError.malformed
        }
        var cursor = firstBoundary.upperBound
        // 跳过 boundary 后的 CRLF
        if cursor + 2 <= body.endIndex && body[cursor..<cursor + 2] == crlf {
            cursor += 2
        }

        while cursor < body.endIndex {
            // header 段在下一个 \r\n\r\n 之前
            guard let headerEnd = body.range(of: dCRLF, in: cursor..<body.endIndex) else {
                throw ParseError.malformed
            }
            let headerData = body[cursor..<headerEnd.lowerBound]
            cursor = headerEnd.upperBound

            // 解析这个 part 的 headers
            let headerText = String(data: headerData, encoding: .utf8) ?? ""
            var name = ""
            var filename = ""
            var contentType = "application/octet-stream"
            for line in headerText.components(separatedBy: "\r\n") where !line.isEmpty {
                let lower = line.lowercased()
                if lower.hasPrefix("content-disposition:") {
                    if let n = Self.extractAttr(line, key: "name") { name = n }
                    if let f = Self.extractAttr(line, key: "filename") { filename = f }
                } else if lower.hasPrefix("content-type:") {
                    if let colon = line.firstIndex(of: ":") {
                        contentType = String(line[line.index(after: colon)...])
                            .trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // body 一直到下一个 `\r\n--<boundary>`
            let endSentinel = Data("\r\n--\(boundary)".utf8)
            guard let endRange = body.range(of: endSentinel, in: cursor..<body.endIndex) else {
                throw ParseError.malformed
            }
            let partBody = body[cursor..<endRange.lowerBound]
            cursor = endRange.upperBound

            if !filename.isEmpty {
                return FilePart(
                    name: name,
                    filename: filename,
                    contentType: contentType,
                    body: Data(partBody)
                )
            }

            // 不是 file 段，跳过；检查是否到 -- 结束符
            if cursor + 2 <= body.endIndex && body[cursor..<cursor + 2] == Data("--".utf8) {
                break
            }
            if cursor + 2 <= body.endIndex && body[cursor..<cursor + 2] == crlf {
                cursor += 2
            }
        }
        throw ParseError.malformed
    }

    private static func extractAttr(_ line: String, key: String) -> String? {
        guard let range = line.range(of: "\(key)=", options: .caseInsensitive) else { return nil }
        var rest = String(line[range.upperBound...])
        if rest.hasPrefix("\"") {
            rest.removeFirst()
            if let endQuote = rest.firstIndex(of: "\"") {
                return String(rest[..<endQuote])
            }
            return rest
        }
        if let sep = rest.firstIndex(where: { $0 == ";" || $0 == " " }) {
            return String(rest[..<sep])
        }
        return rest
    }
}
