import SwiftUI

struct CollectionsView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    @State private var groups: [(Category, [Collection])] = []
    @State private var filter: String?
    @State private var adding = false
    @State private var loaded = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var shown: [(Category, [Collection])] {
        guard let filter else { return groups }
        return groups.filter { $0.0.id == filter }
    }

    private var featured: Collection? { shown.flatMap(\.1).first }

    var body: some View {
        ScrollView {
            if loaded && groups.isEmpty {
                EmptyState(icon: "folder.badge.plus", title: "Group your media", text: "Categories hold collections, like Travel → Kyoto 2025. Start with a category.")
                Button("New category") { adding = true }
                    .buttonStyle(.borderedProminent)
            }

            if groups.count > 1 { chips }

            if let featured {
                NavigationLink(value: featured) { FeaturedCard(collection: featured) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(shown, id: \.0.id) { cat, cols in
                    VStack(alignment: .leading, spacing: 14) {
                        NavigationLink(value: cat) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(cat.name).font(.title2.weight(.bold))
                                Text("\(cols.count)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Text("See all").font(.subheadline).foregroundStyle(Theme.accent)
                            }
                        }
                        .buttonStyle(.plain)

                        if cols.isEmpty {
                            NavigationLink(value: cat) {
                                Label("Add the first collection", systemImage: "folder.badge.plus")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(cols) { c in
                                    NavigationLink(value: c) { CollectionCard(collection: c) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Theme.bg)
        .navigationTitle("Collections")
        .navigationDestination(for: Category.self) { CategoryView(category: $0) }
        .navigationDestination(for: Collection.self) { CollectionView(collection: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $adding) { NewCategorySheet().presentationDetents([.height(300)]) }
        .refreshable { await load() }
        .task(id: model.version) { await load() }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: filter == nil) { filter = nil }
                ForEach(groups, id: \.0.id) { cat, _ in
                    chip(cat.name, selected: filter == cat.id) { filter = cat.id }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule().fill(Theme.gradient)
                    } else {
                        Capsule().fill(Theme.surface)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        await model.run { groups = try await client.allCollections() }
        loaded = true
    }
}

struct CollectionCover: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    let collection: Collection
    @Binding var count: Int

    @State private var items: [Media] = []

    private var cover: Media? { items.first { $0.id == collection.coverId } ?? items.first }

    var body: some View {
        Group {
            if let cover {
                Thumbnail(media: cover, maxPixel: 1280)
            } else {
                Theme.surface.overlay {
                    Image(systemName: "photo.stack").font(.title).foregroundStyle(Theme.raised)
                }
            }
        }
        .task(id: "\(collection.id)-\(model.version)") {
            items = (try? await client.media(collectionId: collection.id)) ?? []
            count = items.count
        }
    }
}

struct CollectionCard: View {
    let collection: Collection
    var width: CGFloat?

    @State private var count = 0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.raised.opacity(0.5))
                .padding(.horizontal, 14)
                .offset(y: -10)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.raised)
                .padding(.horizontal, 7)
                .offset(y: -5)
            CollectionCover(collection: collection, count: $count)
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.name)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(plural(count, "item"))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .padding(12)
                        }
                }
                .card(radius: 18)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
        }
        .padding(.top, 10)
        .frame(width: width)
    }
}

struct FeaturedCard: View {
    let collection: Collection

    @State private var count = 0

    var body: some View {
        CollectionCover(collection: collection, count: $count)
            .frame(height: 260)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FEATURED")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.gradient, in: Capsule())
                        .foregroundStyle(.black)
                    Text(collection.name)
                        .font(.title.weight(.heavy))
                        .lineLimit(2)
                    Text(plural(count, "item"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(18)
            }
            .card(radius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08)))
            .shadow(color: Theme.accent2.opacity(0.25), radius: 24, y: 10)
    }
}


struct NewCategorySheet: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var layout: Layout = .gallery

    var body: some View {
        NavigationStack {
            Form {
                TextField("Travel, Movies, Screenshots…", text: $name)
                Picker("Shown as", selection: $layout) {
                    ForEach(Layout.allCases) { Text($0.label).tag($0) }
                }
            }
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await model.run {
                                _ = try await client.createCategory(name: name.trimmingCharacters(in: .whitespaces), layout: layout)
                                model.refresh()
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct NameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let placeholder: String
    let submit: (String) async -> Void

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form { TextField(placeholder, text: $name) }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                await submit(name.trimmingCharacters(in: .whitespaces))
                                dismiss()
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
        }
        .presentationDetents([.height(220)])
    }
}
