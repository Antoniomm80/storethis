import Foundation

struct GCSObject: Codable, Identifiable {
    let name: String
    let bucket: String?
    let size: String?
    let contentType: String?
    let updated: String?

    var id: String { name }

    var displayName: String {
        if name.hasSuffix("/") {
            return String(name.dropLast()).components(separatedBy: "/").last ?? name
        }
        return name.components(separatedBy: "/").last ?? name
    }

    var isFolder: Bool {
        name.hasSuffix("/")
    }

    var formattedSize: String {
        guard let sizeStr = size, let bytes = Int64(sizeStr) else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct GCSListResponse: Codable {
    let kind: String?
    let prefixes: [String]?
    let items: [GCSObject]?
    let nextPageToken: String?
}
