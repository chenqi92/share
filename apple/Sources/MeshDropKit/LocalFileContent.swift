import Foundation
import UniformTypeIdentifiers

public enum LocalFileContent {
    public static func readableURL(_ url: URL?) -> URL? {
        guard let url = restoredURL(url), url.isFileURL,
              FileManager.default.isReadableFile(atPath: url.path),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
        return url
    }

    static func restoredURL(_ url: URL?) -> URL? {
        #if os(iOS)
        return url.map { rebasedURL($0, container: URL(fileURLWithPath: NSHomeDirectory())) }
        #else
        return url
        #endif
    }

    // iOS changes the data-container UUID on app updates; only rebase app-owned paths.
    static func rebasedURL(_ url: URL, container: URL) -> URL {
        guard url.isFileURL else { return url }
        let parts = url.standardizedFileURL.pathComponents
        let prefix = ["/", "private", "var", "mobile", "Containers", "Data", "Application"]
        let shortPrefix = ["/", "var", "mobile", "Containers", "Data", "Application"]
        let rootCount: Int
        if parts.starts(with: prefix) { rootCount = prefix.count }
        else if parts.starts(with: shortPrefix) { rootCount = shortPrefix.count }
        else { return url }
        guard parts.count > rootCount + 1,
              UUID(uuidString: parts[rootCount]) != nil,
              ["Documents", "Library", "tmp"].contains(parts[rootCount + 1]) else { return url }
        return parts.dropFirst(rootCount + 1).reduce(container) { $0.appendingPathComponent($1) }
    }

    static func retainTemporaryAttachment(_ url: URL, id: UUID) throws -> URL {
        #if os(iOS)
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                 appropriateFor: nil, create: true)
        return try retainTemporaryAttachment(url, id: id, temporaryDirectory: fm.temporaryDirectory,
                                             attachmentsDirectory: support.appendingPathComponent("MeshDrop/Attachments"))
        #else
        return url
        #endif
    }

    static func retainTemporaryAttachment(_ url: URL, id: UUID, temporaryDirectory: URL,
                                           attachmentsDirectory: URL) throws -> URL {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let temporaryPath = temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        guard url.isFileURL, path.hasPrefix(temporaryPath) else { return url }
        let fm = FileManager.default
        let directory = attachmentsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: destination.path) { try fm.moveItem(at: url, to: destination) }
        return destination
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
