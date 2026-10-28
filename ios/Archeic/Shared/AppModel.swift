import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PickedFile: Transferable {
    let url: URL
    let name: String
    let contentType: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copy(received.file, type: .movie)
        }
        FileRepresentation(importedContentType: .image) { received in
            try copy(received.file, type: .image)
        }
    }

    private static func copy(_ file: URL, type: UTType) throws -> PickedFile {
        let dest = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(file.lastPathComponent)")
        try FileManager.default.copyItem(at: file, to: dest)
        let fileType = UTType(filenameExtension: file.pathExtension) ?? type
        let mime = fileType.preferredMIMEType ?? (type == .movie ? "video/quicktime" : "image/jpeg")
        return PickedFile(url: dest, name: file.lastPathComponent, contentType: mime)
    }
}

@MainActor
@Observable
final class AppModel {
    var connected = false
    var version = 0
    var notice: String?
    var uploading: (done: Int, total: Int)?

    func refresh() { version += 1 }

    func notify(_ text: String) {
        notice = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if notice == text { notice = nil }
        }
    }

    func run(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            notify(error.localizedDescription)
        }
    }

    func upload(_ items: [PhotosPickerItem], client: Client, into collectionId: String? = nil) async {
        guard !items.isEmpty else { return }
        uploading = (0, items.count)
        var ids: [String] = []
        await run {
            for item in items {
                guard let file = try await item.loadTransferable(type: PickedFile.self) else { continue }
                defer { try? FileManager.default.removeItem(at: file.url) }
                let m = try await client.upload(file: file.url, name: file.name, contentType: file.contentType)
                ids.append(m.id)
                uploading = (ids.count, items.count)
            }
            if let collectionId, !ids.isEmpty {
                try await client.addItems(collectionId: collectionId, mediaIds: ids)
            }
        }
        uploading = nil
        if !ids.isEmpty { notify("Uploaded \(plural(ids.count, "file"))") }
        refresh()
    }
}
