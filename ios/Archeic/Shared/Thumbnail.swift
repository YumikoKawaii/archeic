import ImageIO
import SwiftUI

actor ImageStore {
    static let shared = ImageStore()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 1 << 30)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: config)
    }()
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 160 << 20
        return c
    }()
    private var running: [String: Task<UIImage?, Never>] = [:]

    func image(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)#\(Int(maxPixel))"
        if let hit = cache.object(forKey: key as NSString) { return hit }
        if let task = running[key] { return await task.value }
        let session = session
        let task = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            guard let (data, _) = try? await session.data(from: url) else { return nil }
            return Self.decode(data, maxPixel: maxPixel)
        }
        running[key] = task
        let img = await task.value
        running[key] = nil
        if let img, let cg = img.cgImage {
            cache.setObject(img, forKey: key as NSString, cost: cg.bytesPerRow * cg.height)
        }
        return img
    }

    private static func decode(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct Thumbnail: View {
    @Environment(Client.self) private var client
    let media: Media
    var maxPixel: CGFloat = 400
    var fill = true
    var original = false

    @State private var image: UIImage?

    var body: some View {
        (fill ? Theme.surface : Color.black)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fill ? .fill : .fit)
                } else if !fill {
                    ProgressView()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if media.isVideo && fill {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
            .task(id: media.id) {
                let size = maxPixel > 512 ? 1280 : 512
                image = await ImageStore.shared.image(client.thumbURL(media.id, size: size), maxPixel: min(maxPixel, CGFloat(size)))
                guard original, !media.isVideo, !Task.isCancelled else { return }
                if let full = await ImageStore.shared.image(client.contentURL(media.id), maxPixel: maxPixel) {
                    image = full
                }
            }
    }
}
