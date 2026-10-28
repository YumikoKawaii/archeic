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
    @State private var touch = 0
    @State private var zoomed = false
    @State private var pull: CGFloat = 0
    @State private var details = false
    @State private var confirming = false
    @State private var playing = false

    private var media: Media? { items.first { $0.id == current } }
    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }
    private var progress: CGFloat { min(max(pull, 0) / 300, 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ambient
                pager
                    .frame(height: details ? geo.size.height * 0.52 : geo.size.height)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: details ? 0 : pull)
                    .scaleEffect(1 - progress * 0.15)
                if details, let media {
                    InfoPanel(media: media)
                        .frame(height: geo.size.height * 0.48 + geo.safeAreaInsets.bottom)
                        .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea()
        }
        .simultaneousGesture(drag, including: zoomed ? .subviews : .all)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { chrome.toggle() }
            touch += 1
        }
        .overlay(alignment: .top) { if chrome && pull == 0 && !details { topBar } }
        .overlay(alignment: .bottom) { if chrome && pull == 0 && !details { bottomBar } }
        .statusBarHidden(!chrome || details)
        .presentationBackground(.clear)
        .onAppear { current = start.id }
        .onChange(of: current) {
            zoomed = false
            playing = false
            touch += 1
        }
        .onChange(of: playing) { _, on in
            withAnimation(.easeOut(duration: 0.2)) { chrome = !on }
        }
        .onChange(of: zoomed) { _, on in
            if on { withAnimation(.easeOut(duration: 0.2)) { chrome = false } }
        }
        .task(id: touch) {
            guard chrome else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, !confirming else { return }
            withAnimation(.easeOut(duration: 0.4)) { chrome = false }
        }
        .confirmationDialog("Delete this \(media?.isVideo == true ? "video" : "photo") permanently?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("It's removed from storage and every collection. This can't be undone.")
        }
    }

    private var pager: some View {
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
    }

    @ViewBuilder
    private var ambient: some View {
        ZStack {
            Color.black
            if let media, !media.isVideo {
                Thumbnail(media: media, maxPixel: 64)
                    .blur(radius: 50)
                    .scaleEffect(1.4)
                    .opacity(0.55)
                    .id(media.id)
                    .transition(.opacity)
            }
            Color.black.opacity(0.35)
        }
        .animation(.easeInOut(duration: 0.35), value: current)
        .opacity(1 - progress)
        .ignoresSafeArea()
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { v in
                guard !zoomed, abs(v.translation.height) > abs(v.translation.width) else { return }
                if details || v.translation.height < 0 { return }
                pull = v.translation.height
            }
            .onEnded { v in
                guard !zoomed, abs(v.translation.height) > abs(v.translation.width) else {
                    withAnimation(.spring(duration: 0.3)) { pull = 0 }
                    return
                }
                let dy = v.translation.height
                if details {
                    if dy > 60 { withAnimation(.spring(duration: 0.35)) { details = false } }
                } else if dy < -60, media?.isVideo != true {
                    withAnimation(.spring(duration: 0.35)) { details = true }
                } else if pull > 120 || v.predictedEndTranslation.height > 400 {
                    dismiss()
                    return
                }
                withAnimation(.spring(duration: 0.3)) { pull = 0 }
            }
    }

    private var topBar: some View {
        ZStack {
            Text("\(index + 1) / \(items.count)")
                .font(.footnote.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45), in: Capsule())
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.45), in: Circle())
                }
                Spacer()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .transition(.opacity)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Filmstrip(items: items, current: $current)
            HStack(spacing: 6) {
                if let media {
                    ShareLink(item: client.contentURL(media.id)) { dock("square.and.arrow.up") }
                }
                if media?.isVideo != true {
                    Button { withAnimation(.spring(duration: 0.35)) { details = true } } label: { dock("info.circle") }
                }
                if let collectionId {
                    Button { setCover(collectionId) } label: { dock("star") }
                }
                menu
            }
            .padding(6)
            .background(Color.black.opacity(0.55), in: Capsule())
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.bottom, playing || media?.isVideo == true ? 60 : 8)
        .transition(.opacity)
    }

    private func dock(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.body.weight(.medium))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private var menu: some View {
        Menu {
            Button { save() } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
            if let collectionId {
                Button { removeFromCollection(collectionId) } label: { Label("Remove from collection", systemImage: "minus.circle") }
            }
            Divider()
            Button(role: .destructive) { confirming = true } label: { Label("Delete…", systemImage: "trash") }
        } label: {
            dock("ellipsis")
        }
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
                LazyHStack(alignment: .bottom, spacing: 2) {
                    ForEach(items) { m in
                        let on = m.id == current
                        Thumbnail(media: m, maxPixel: 120)
                            .frame(width: on ? 30 : 20, height: on ? 40 : 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: on ? 1.5 : 0))
                            .opacity(on ? 1 : 0.55)
                            .id(m.id)
                            .onTapGesture { current = m.id }
                    }
                }
                .padding(.horizontal, 16)
                .animation(.snappy(duration: 0.2), value: current)
            }
            .frame(height: 42)
            .onChange(of: current, initial: true) { _, id in
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct InfoPanel: View {
    @Environment(Client.self) private var client
    let media: Media

    @State private var dimensions: String?
    @State private var collections: [Collection] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
            Text(media.name)
                .font(.headline)
                .lineLimit(2)
                .textSelection(.enabled)
            VStack(spacing: 10) {
                if let dimensions { row("Resolution", dimensions) }
                row("Size", "\(ByteCountFormatter.string(fromByteCount: Int64(media.size) ?? 0, countStyle: .file)) · \(media.contentType)")
                if let t = media.createTime {
                    row("Uploaded", t.formatted(date: .abbreviated, time: .shortened))
                }
            }
            if !collections.isEmpty {
                Text("In collections")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(collections) { c in
                            Text(c.name)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.raised, in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .task(id: media.id) {
            collections = (try? await client.collections(containing: media.id)) ?? []
        }
        .task(id: media.id) {
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
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
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
                .onTapGesture(count: 2) { at in
                    withAnimation(.spring(duration: 0.3)) {
                        if scale > 1 {
                            reset()
                        } else {
                            scale = 2.5
                            base = 2.5
                            offset = CGSize(width: (geo.size.width / 2 - at.x) * 1.5, height: (geo.size.height / 2 - at.y) * 1.5)
                            lastOffset = offset
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
    @State private var retries = 0
    @State private var failed = false

    private let maxRetries = 4

    var body: some View {
        VideoPlayer(player: player)
            .overlay {
                if failed {
                    Button {
                        retries = 0
                        failed = false
                        recover()
                    } label: {
                        Label("Couldn't play. Tap to retry", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.6), in: Capsule())
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onChange(of: active, initial: true) { _, on in
                if on { player?.play() } else { player?.pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
                if active, (note.object as? AVPlayerItem) === player?.currentItem { playing = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)) { note in
                if active, (note.object as? AVPlayerItem) === player?.currentItem { recover() }
            }
            .task(id: active) {
                guard active, let player else { return }
                for await rate in player.publisher(for: \.rate).values {
                    playing = rate > 0
                }
            }
            .task(id: active) {
                guard active, let player else { return }
                for await status in player.publisher(for: \.currentItem?.status).values where status == .failed {
                    recover()
                }
            }
            .task(id: active) {
                guard active, let player else { return }
                var waiting = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                        waiting += 1
                        if waiting >= 8 {
                            waiting = 0
                            recover()
                        }
                    } else {
                        waiting = 0
                        if player.timeControlStatus == .playing { retries = 0 }
                    }
                }
            }
            .onDisappear { player?.pause() }
    }

    private func recover() {
        guard let player, active else { return }
        guard retries < maxRetries else {
            failed = true
            return
        }
        retries += 1
        let at = player.currentTime()
        let delay = Double(1 << (retries - 1)) * 0.5
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard active else { return }
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            if at.isValid, at.seconds > 0 {
                await player.seek(to: at, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            player.play()
        }
    }
}
