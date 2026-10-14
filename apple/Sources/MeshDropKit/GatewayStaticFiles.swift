import Foundation

enum GatewayStaticFiles {
    struct Resource {
        let body: Data
        let contentType: String
    }

    static func load(path: String, root: URL) -> Resource? {
        let rawPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        guard let decoded = rawPath.removingPercentEncoding,
              decoded.hasPrefix("/"), !decoded.contains("\\"),
              !decoded.unicodeScalars.contains(where: { $0.value < 32 }),
              !decoded.split(separator: "/").contains("..") else { return nil }
        let relativePath = decoded == "/" ? "index.html" : String(decoded.dropFirst())
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let file = base.appendingPathComponent(relativePath).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(base.path + "/"),
              let type = contentTypes[file.pathExtension.lowercased()],
              (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let body = try? Data(contentsOf: file) else { return nil }
        return Resource(body: body, contentType: type)
    }

    private static let contentTypes = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
        "css": "text/css; charset=utf-8", "json": "application/json",
        "webmanifest": "application/manifest+json", "svg": "image/svg+xml",
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
        "webp": "image/webp", "ico": "image/x-icon", "woff2": "font/woff2",
    ]
}
