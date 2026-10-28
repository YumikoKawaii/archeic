import SwiftUI

struct HomeView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Binding var tab: Int

    @State private var media: [Media] = []
    @State private var collections: [Collection] = []
    @State private var spot = 0
    @State private var settings = false
    @State private var viewing: Media?
    @State private var appeared = false

    private var photos: [Media] { media.filter { !$0.isVideo } }
    private var featured: [Media] { Array(photos.prefix(6)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                shortcuts
                    .padding(.horizontal, 16)
                    .offset(y: -18)
                if !media.isEmpty { recent }
                if !collections.isEmpty { albums }
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.bg)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { settings = true } label: { Image(systemName: "gearshape") }
            }
            ToolbarItem(placement: .topBarTrailing) { UploadButton() }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .fullScreenCover(item: $viewing) { m in Viewer(items: media, start: m) }
        .task(id: model.version) { await load() }
        .task(id: featured.count) {
            guard featured.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeInOut(duration: 1.4)) { spot = (spot + 1) % featured.count }
            }
        }
        .refreshable { await load() }
    }

    private var hero: some View {
        GeometryReader { geo in
            let stretch = max(0, geo.frame(in: .scrollView).minY)
            ZStack(alignment: .bottomLeading) {
                if featured.isEmpty {
                    Aurora()
                } else {
                    ForEach(Array(featured.enumerated()), id: \.element.id) { i, m in
                        Thumbnail(media: m, maxPixel: 1600)
                            .scaleEffect(i == spot ? 1 : 1.12)
                            .opacity(i == spot ? 1 : 0)
                    }
                }
                LinearGradient(
                    stops: [
                        .init(color: Theme.bg.opacity(0.55), location: 0),
                        .init(color: .clear, location: 0.25),
                        .init(color: .clear, location: 0.45),
                        .init(color: Theme.bg.opacity(0.75), location: 0.75),
                        .init(color: Theme.bg, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                heroText
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
            }
            .frame(width: geo.size.width, height: geo.size.height + stretch)
            .offset(y: -stretch)
            .contentShape(Rectangle())
            .onTapGesture { if let m = featured[safe: spot] { viewing = m } }
        }
        .frame(height: 560)
        .overlay(alignment: .top) {
            if featured.count > 1 {
                HStack(spacing: 4) {
                    ForEach(featured.indices, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == spot ? 1 : 0.25))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.9).delay(0.1)) { appeared = true } }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2.2)
                .foregroundStyle(Theme.muted)
            Text("archeic")
                .font(.system(size: 76, weight: .heavy, design: .default))
                .tracking(-3.5)
                .foregroundStyle(Theme.gradient)
                .shadow(color: Theme.accent2.opacity(0.4), radius: 24, y: 4)
            HStack(spacing: 10) {
                stat(photos.count, "photo")
                dot
                stat(media.count - photos.count, "video")
                dot
                stat(collections.count, "collection")
            }
            if let first = media.last?.createTime {
                Text("Archiving since \(first.formatted(.dateTime.year()))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func stat(_ n: Int, _ word: String) -> some View {
        (Text("\(n) ").font(.headline.weight(.bold)) + Text(n == 1 ? word : word + "s").foregroundStyle(Theme.muted))
            .font(.subheadline)
    }

    private var dot: some View {
        Circle().fill(Theme.raised).frame(width: 4, height: 4)
    }

    private var shortcuts: some View {
        HStack(spacing: 10) {
            shortcut("square.grid.2x2.fill", "Library", plural(media.count, "item")) { tab = 1 }
            shortcut("folder.fill", "Collections", plural(collections.count, "album")) { tab = 2 }
        }
    }

    private func shortcut(_ icon: String, _ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.gradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHead("Recently added") { tab = 1 }
            let list = Array(media.prefix(7))
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    tile(list[safe: 0], big: true)
                        .gridCellColumns(2)
                    VStack(spacing: 4) {
                        tile(list[safe: 1])
                        tile(list[safe: 2])
                    }
                }
                if list.count > 3 {
                    GridRow {
                        tile(list[safe: 3])
                        tile(list[safe: 4])
                        tile(list[safe: 5])
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func tile(_ m: Media?, big: Bool = false) -> some View {
        if let m {
            Thumbnail(media: m, maxPixel: big ? 800 : 400)
                .aspectRatio(1, contentMode: .fit)
                .card(radius: big ? 18 : 12)
                .onTapGesture { viewing = m }
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }

    private var albums: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHead("Collections") { tab = 2 }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(collections) { c in
                        NavigationLink(value: c) { CollectionCard(collection: c, width: 150) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationDestination(for: Collection.self) { CollectionView(collection: $0) }
        }
        .padding(.top, 28)
    }

    private func sectionHead(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(.title2.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<5: "Late night"
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private func load() async {
        await model.run {
            media = try await client.media()
            collections = try await client.allCollections().flatMap(\.1)
        }
    }
}

struct Aurora: View {
    var body: some View {
        TimelineView(.animation) { t in
            let s = t.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.bg
                blob(Theme.accent, x: 0.25 + 0.1 * sin(s / 3), y: 0.3)
                blob(Theme.accent2, x: 0.75, y: 0.4 + 0.1 * cos(s / 4))
                blob(Theme.accent3, x: 0.5 + 0.15 * sin(s / 5), y: 0.72)
            }
            .blur(radius: 50)
        }
    }

    private func blob(_ color: Color, x: Double, y: Double) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: geo.size.width * 0.7)
                .position(x: geo.size.width * x, y: geo.size.height * y)
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
