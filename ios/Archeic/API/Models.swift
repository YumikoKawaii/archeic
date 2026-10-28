import Foundation

enum Kind: String, Codable, Sendable {
    case unspecified = "KIND_UNSPECIFIED"
    case image = "KIND_IMAGE"
    case video = "KIND_VIDEO"
}

enum Layout: String, Codable, Sendable, CaseIterable, Identifiable {
    case gallery = "LAYOUT_GALLERY"
    case library = "LAYOUT_LIBRARY"
    case episodic = "LAYOUT_EPISODIC"
    case timeline = "LAYOUT_TIMELINE"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gallery: "Gallery"
        case .library: "Library"
        case .episodic: "Episodic"
        case .timeline: "Timeline"
        }
    }
}

struct Media: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String = ""
    var kind: Kind = .unspecified
    var contentType: String = ""
    var size: String = "0"
    var createTime: Date?

    var isVideo: Bool { kind == .video }
}

struct Category: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var slug: String = ""
    var name: String = ""
    var layout: Layout?
    var position: Int?
}

struct Collection: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var categoryId: String = ""
    var parentId: String?
    var name: String = ""
    var coverId: String?
}
