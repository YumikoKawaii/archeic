import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
@Observable
final class Client {
    static let knownServers = [
        "https://192.168.1.165:8443",
        "https://172.20.10.8:8443",
        "https://192.168.100.147:8443",
    ]
    static let defaultServer = knownServers[0]

    var server: String {
        didSet { UserDefaults.standard.set(server, forKey: "server") }
    }

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init() {
        server = UserDefaults.standard.string(forKey: "server") ?? Self.defaultServer
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: raw) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath, debugDescription: raw))
        }
    }

    var base: URL { URL(string: server) ?? URL(string: Self.defaultServer)! }

    func contentURL(_ id: String) -> URL {
        base.appending(path: "api/media/\(id)/content")
    }

    private func call<Req: Encodable, Res: Decodable>(_ service: String, _ method: String, _ body: Req) async throws -> Res {
        var req = URLRequest(url: base.appending(path: "api/archeic.v1.\(service)/\(method)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, res) = try await session.data(for: req)
        try check(data, res)
        return try decoder.decode(Res.self, from: data)
    }

    private func check(_ data: Data, _ res: URLResponse) throws {
        guard let http = res as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        struct Failure: Decodable { let message: String? }
        let message = (try? decoder.decode(Failure.self, from: data))?.message ?? String(data: data, encoding: .utf8) ?? ""
        throw APIError(message: message.isEmpty ? "Request failed (\(http.statusCode))" : message)
    }

    func media(kind: Kind = .unspecified, collectionId: String = "") async throws -> [Media] {
        struct Req: Encodable { let kind: Kind; let collectionId: String }
        struct Res: Decodable { var media: [Media]? }
        let res: Res = try await call("MediaService", "List", Req(kind: kind, collectionId: collectionId))
        return res.media ?? []
    }

    func deleteMedia(_ id: String) async throws {
        struct Req: Encodable { let id: String }
        struct Res: Decodable {}
        let _: Res = try await call("MediaService", "Delete", Req(id: id))
    }

    func upload(file: URL, name: String, contentType: String) async throws -> Media {
        let boundary = "archeic-\(UUID().uuidString)"
        var req = URLRequest(url: base.appending(path: "api/media"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = FileManager.default.temporaryDirectory.appending(path: "upload-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: body.path(), contents: nil)
        defer { try? FileManager.default.removeItem(at: body) }
        let out = try FileHandle(forWritingTo: body)
        out.write(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: \(contentType)\r\n\r\n".utf8))
        let input = try FileHandle(forReadingFrom: file)
        while let chunk = try input.read(upToCount: 4 << 20), !chunk.isEmpty {
            out.write(chunk)
        }
        try input.close()
        out.write(Data("\r\n--\(boundary)--\r\n".utf8))
        try out.close()

        let (data, res) = try await session.upload(for: req, fromFile: body)
        try check(data, res)
        return try decoder.decode(Media.self, from: data)
    }

    func categories() async throws -> [Category] {
        struct Req: Encodable {}
        struct Res: Decodable { var categories: [Category]? }
        let res: Res = try await call("CategoryService", "List", Req())
        return res.categories ?? []
    }

    func createCategory(name: String, layout: Layout) async throws -> Category {
        struct Req: Encodable { let name: String; let slug: String; let layout: Layout }
        struct Res: Decodable { let category: Category }
        let res: Res = try await call("CategoryService", "Create", Req(name: name, slug: slugify(name), layout: layout))
        return res.category
    }

    func deleteCategory(_ id: String) async throws {
        struct Req: Encodable { let id: String }
        struct Res: Decodable {}
        let _: Res = try await call("CategoryService", "Delete", Req(id: id))
    }

    func collections(categoryId: String, parentId: String? = nil) async throws -> [Collection] {
        struct Req: Encodable { let categoryId: String; let parentId: String? }
        struct Res: Decodable { var collections: [Collection]? }
        let res: Res = try await call("CollectionService", "List", Req(categoryId: categoryId, parentId: parentId))
        return res.collections ?? []
    }

    func collection(_ id: String) async throws -> Collection {
        struct Req: Encodable { let id: String }
        struct Res: Decodable { let collection: Collection }
        let res: Res = try await call("CollectionService", "Get", Req(id: id))
        return res.collection
    }

    func createCollection(categoryId: String, parentId: String?, name: String) async throws -> Collection {
        struct Req: Encodable { let categoryId: String; let parentId: String?; let name: String }
        struct Res: Decodable { let collection: Collection }
        let res: Res = try await call("CollectionService", "Create", Req(categoryId: categoryId, parentId: parentId, name: name))
        return res.collection
    }

    func setCover(collectionId: String, mediaId: String) async throws {
        struct Req: Encodable { let id: String; let coverId: String }
        struct Res: Decodable {}
        let _: Res = try await call("CollectionService", "Update", Req(id: collectionId, coverId: mediaId))
    }

    func deleteCollection(_ id: String) async throws {
        struct Req: Encodable { let id: String }
        struct Res: Decodable {}
        let _: Res = try await call("CollectionService", "Delete", Req(id: id))
    }

    func addItems(collectionId: String, mediaIds: [String]) async throws {
        struct Req: Encodable { let collectionId: String; let mediaIds: [String] }
        struct Res: Decodable {}
        let _: Res = try await call("CollectionService", "AddItems", Req(collectionId: collectionId, mediaIds: mediaIds))
    }

    func removeItems(collectionId: String, mediaIds: [String]) async throws {
        struct Req: Encodable { let collectionId: String; let mediaIds: [String] }
        struct Res: Decodable {}
        let _: Res = try await call("CollectionService", "RemoveItems", Req(collectionId: collectionId, mediaIds: mediaIds))
    }

    func allCollections() async throws -> [(Category, [Collection])] {
        var out: [(Category, [Collection])] = []
        for c in try await categories() {
            out.append((c, try await collections(categoryId: c.id)))
        }
        return out
    }
}

func slugify(_ name: String) -> String {
    let lowered = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    var out = ""
    for ch in lowered {
        if ch.isASCII && (ch.isLetter || ch.isNumber) {
            out.append(ch)
        } else if !out.hasSuffix("-") && !out.isEmpty {
            out.append("-")
        }
    }
    while out.hasSuffix("-") { out.removeLast() }
    return out.isEmpty ? "category" : out
}
