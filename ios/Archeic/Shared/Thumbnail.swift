import AVFoundation
import ImageIO
import SwiftUI

actor ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private var running: [String: Task<UIImage?, Never>] = [:]

    func image(_ url: URL, maxPixel: CGFloat, video: Bool) async -> UIImage? {
        let key = "\(url.absoluteString)#\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        if let task = running[key as String] { return await task.value }
        let task = Task<UIImage?, Never> {
            video ? await Self.frame(url, maxPixel: maxPixel) : await Self.downsample(url, maxPixel: maxPixel)
        }
        running[key as String] = task
        let img = await task.value
        running[key as String] = nil
        if let img { cache.setObject(img, forKey: key) }
        return img
    }

    private static func downsample(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func frame(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let (cg, _) = try? await gen.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct Thumbnail: View {
    @Environment(Client.self) private var client
    let media: Media
    var maxPixel: CGFloat = 400
    var fill = true

    @State private var image: UIImage?

    var body: some View {
        (fill ? Theme.surface : Color.black)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fill ? .fill : .fit)
                        .transition(.opacity)
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
                let url = client.contentURL(media.id)
                let img = await ImageStore.shared.image(url, maxPixel: maxPixel, video: media.isVideo)
                withAnimation(.easeOut(duration: 0.25)) { image = img }
            }
    }
}
