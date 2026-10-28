import AVKit
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
    @State private var confirming = false

    private var media: Media? { items.first { $0.id == current } }
    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }

    var body: some View {
        TabView(selection: $current) {
            ForEach(items) { m in
                Group {
                    if m.isVideo {
                        VideoPage(url: client.contentURL(m.id), active: current == m.id)
                    } else {
                        ZoomImage(media: m)
                    }
                }
                .tag(m.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { chrome.toggle() } }
        .overlay(alignment: .top) { if chrome { topBar } }
        .overlay(alignment: .bottom) { if chrome { bottomBar } }
        .statusBarHidden(!chrome)
        .onAppear { current = start.id }
        .confirmationDialog("Delete this item permanently?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 40, height: 40)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(media?.createTime?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.subheadline.weight(.semibold))
                Text("\(index + 1) of \(items.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if let media {
                ShareLink(item: client.contentURL(media.id)) {
                    Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold)).frame(width: 40, height: 40)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .transition(.opacity)
    }

    private var bottomBar: some View {
        HStack {
            if let collectionId, let media {
                Button {
                    Task {
                        await model.run {
                            try await client.setCover(collectionId: collectionId, mediaId: media.id)
                            model.notify("Set as cover")
                            model.refresh()
                        }
                    }
                } label: {
                    Label("Cover", systemImage: "photo.badge.checkmark")
                }
            }
            Spacer()
            Button(role: .destructive) { confirming = true } label: {
                Image(systemName: "trash").frame(width: 40, height: 40)
            }
            .tint(Theme.danger)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .transition(.opacity)
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

struct ZoomImage: View {
    let media: Media

    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Thumbnail(media: media, maxPixel: 2400, fill: false, original: true)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { v in scale = min(max(base * v.magnification, 1), 8) }
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
                        if scale > 1 { reset() } else { scale = 2.5; base = 2.5 }
                    }
                }
        }
    }

    private func reset() {
        withAnimation(.spring(duration: 0.3)) {
            scale = 1
            base = 1
            offset = .zero
            lastOffset = .zero
        }
    }
}

struct VideoPage: View {
    let url: URL
    let active: Bool

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onChange(of: active, initial: true) { _, on in
                if on { player?.play() } else { player?.pause() }
            }
            .onDisappear { player?.pause() }
    }
}
