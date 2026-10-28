import AVKit
import ImageIO
import Photos
import SwiftUI

struct Viewer: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let items: [Media]
    let start: Media
    var collectionId: String?

    @State private var current: String = ""
    @State private var chrome = true
    @State private var zoomed = false
    @State private var pull: CGFloat = 0
    @State private var confirming = false
    @State private var info = false
    @State private var playing = false

    private var media: Media? { items.first { $0.id == current } }
    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }
    private var progress: CGFloat { min(abs(pull) / 300, 1) }

    var body: some View {
        TabView(selection: $current) {
            ForEach(items) { m in
                Group {
                    if m.isVideo {
                        VideoPage(url: client.contentURL(m.id), active: current == m.id, playing: $playing)
                    } else {
                        ZoomImage(media: m, zoomed: $zoomed)
                    }
                }
                .tag(m.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .offset(y: pull)
        .scaleEffect(1 - progress * 0.15)
        .background(Color.black.opacity(1 - progress).ignoresSafeArea())
        .ignoresSafeArea()
        .simultaneousGesture(dismissDrag, including: zoomed ? .subviews : .all)
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { chrome.toggle() } }
        .overlay(alignment: .top) { if chrome && pull == 0 { topBar } }
        .overlay(alignment: .bottom) { if chrome && pull == 0 { bottomBar } }
        .statusBarHidden(!chrome)
        .presentationBackground(.clear)
        .onAppear { current = start.id }
        .onChange(of: current) { zoomed = false }
        .sheet(isPresented: $info) {
            if let media { InfoSheet(media: media).presentationDetents([.medium]) }
        }
        .confirmationDialog("Delete this \(media?.isVideo == true ? "video" : "photo") permanently?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("It's removed from storage and every collection. This can't be undone.")
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { v in
                guard !zoomed, abs(v.translation.height) > abs(v.translation.width) else { return }
                pull = v.translation.height
            }
            .onEnded { v in
                if abs(pull) > 120 || abs(v.predictedEndTranslation.height) > 400 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { pull = 0 }
                }
            }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(media?.createTime?.formatted(.dateTime.day().month(.abbreviated).hour().minute()) ?? "")
                    .font(.subheadline.weight(.semibold))
                Text("\(index + 1) of \(items.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            menu
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .background(LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .transition(.opacity)
    }

    private var menu: some View {
        Menu {
            Button { save() } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
            if let collectionId {
                Button { setCover(collectionId) } label: { Label("Set as cover", systemImage: "photo.badge.checkmark") }
                Button { removeFromCollection(collectionId) } label: { Label("Remove from collection", systemImage: "minus.circle") }
            }
            Divider()
            Button(role: .destructive) { confirming = true } label: { Label("Delete…", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis").font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack {
                if let media {
                    ShareLink(item: client.contentURL(media.id)) { action("square.and.arrow.up", "Share") }
                }
                Button { info = true } label: { action("info.circle", "Info") }
                if let collectionId {
                    Button { setCover(collectionId) } label: { action("star", "Cover") }
                }
            }
            .buttonStyle(.plain)
            if !(media?.isVideo == true && playing) {
                Filmstrip(items: items, current: $current)
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 24)
        .padding(.bottom, 4)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .transition(.opacity)
    }

    private func action(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2.weight(.medium))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }

    private func setCover(_ collectionId: String) {
        guard let media else { return }
        Task {
            await model.run {
                try await client.setCover(collectionId: collectionId, mediaId: media.id)
                model.notify("Set as cover")
                model.refresh()
            }
        }
    }

    private func removeFromCollection(_ collectionId: String) {
        guard let media else { return }
        Task {
            await model.run {
                try await client.removeItems(collectionId: collectionId, mediaIds: [media.id])
                model.notify("Removed from collection")
                model.refresh()
                dismiss()
            }
        }
    }

    private func save() {
        guard let media else { return }
        Task {
            await model.run {
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    throw APIError(message: "Allow Archeic to add to Photos in Settings")
                }
                let (tmp, _) = try await URLSession.shared.download(from: client.contentURL(media.id))
                let ext = media.name.split(separator: ".").last.map(String.init) ?? (media.isVideo ? "mp4" : "jpg")
                let file = FileManager.default.temporaryDirectory.appending(path: "\(media.id).\(ext)")
                try? FileManager.default.removeItem(at: file)
                try FileManager.default.moveItem(at: tmp, to: file)
                defer { try? FileManager.default.removeItem(at: file) }
                try await PHPhotoLibrary.shared().performChanges {
                    if media.isVideo {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file)
                    } else {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: file)
                    }
                }
                model.notify("Saved to Photos")
            }
        }
    }

    private func delete() {
        guard let media else { return }
        Task {
            await model.run {
                try await client.deleteMedia(media.id)
                model.notify("Deleted")
                model.refresh()
                dismiss()
            }
        }
    }
}

struct Filmstrip: View {
    let items: [Media]
    @Binding var current: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 3) {
                    ForEach(items) { m in
                        let on = m.id == current
                        Thumbnail(media: m, maxPixel: 160)
                            .frame(width: on ? 44 : 30, height: 44)
                            .card(radius: 6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: on ? 2 : 0))
                            .opacity(on ? 1 : 0.6)
                            .id(m.id)
                            .onTapGesture { current = m.id }
                    }
                }
                .padding(.horizontal, 16)
                .animation(.snappy(duration: 0.2), value: current)
            }
            .frame(height: 48)
            .onChange(of: current, initial: true) { _, id in
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct InfoSheet: View {
    @Environment(Client.self) private var client
    let media: Media

    @State private var dimensions: String?

    var body: some View {
        NavigationStack {
            List {
                row("Name", media.name)
                row("Type", media.contentType)
                row("Size", ByteCountFormatter.string(fromByteCount: Int64(media.size) ?? 0, countStyle: .file))
                if let dimensions { row("Resolution", dimensions) }
                if let t = media.createTime {
                    row("Uploaded", t.formatted(date: .long, time: .shortened))
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: media.id) {
            guard !media.isVideo else {
                let tracks = try? await AVURLAsset(url: client.contentURL(media.id)).loadTracks(withMediaType: .video)
                if let size = try? await tracks?.first?.load(.naturalSize) {
                    dimensions = "\(Int(abs(size.width))) × \(Int(abs(size.height)))"
                }
                return
            }
            var req = URLRequest(url: client.contentURL(media.id))
            req.setValue("bytes=0-131071", forHTTPHeaderField: "Range")
            guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
            let src = CGImageSourceCreateIncremental(nil)
            CGImageSourceUpdateData(src, data as CFData, false)
            if let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
               let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int {
                dimensions = "\(w) × \(h)"
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }
}

struct ZoomImage: View {
    let media: Media
    @Binding var zoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Thumbnail(media: media, maxPixel: 8192, fill: false, original: true)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { v in
                            scale = min(max(base * v.magnification, 1), 8)
                            zoomed = scale > 1
                        }
                        .onEnded { _ in
                            base = scale
                            if scale <= 1 { reset() }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            guard scale > 1 else { return }
                            offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
                        }
                        .onEnded { _ in lastOffset = offset },
                    including: scale > 1 ? .all : .subviews
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        if scale > 1 {
                            reset()
                        } else {
                            scale = 2.5
                            base = 2.5
                            zoomed = true
                        }
                    }
                }
        }
        .onDisappear { reset() }
    }

    private func reset() {
        withAnimation(.spring(duration: 0.3)) {
            scale = 1
            base = 1
            offset = .zero
            lastOffset = .zero
        }
        zoomed = false
    }
}

struct VideoPage: View {
    let url: URL
    let active: Bool
    @Binding var playing: Bool

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onChange(of: active, initial: true) { _, on in
                if on { player?.play() } else { player?.pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { _ in
                if active { playing = false }
            }
            .task(id: active) {
                guard active, let player else { return }
                for await rate in player.publisher(for: \.rate).values {
                    playing = rate > 0
                }
            }
            .onDisappear { player?.pause() }
    }
}
