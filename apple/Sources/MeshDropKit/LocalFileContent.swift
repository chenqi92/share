import Foundation
import UniformTypeIdentifiers

public enum LocalFileContent {
    public static func readableURL(_ url: URL?) -> URL? {
        guard let url, url.isFileURL,
              FileManager.default.isReadableFile(atPath: url.path),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
        return url
    }

    public static func isVideo(name: String) -> Bool {
        UTType(filenameExtension: (name as NSString).pathExtension)?.conforms(to: .movie) == true
    }

    static func markdownText(_ url: URL) -> String? {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()),
              let file = readableURL(url),
              let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        // Larger or non-UTF-8 files remain available through Quick Look.
        guard let data = try? handle.read(upToCount: 512_001), data.count <= 512_000 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
