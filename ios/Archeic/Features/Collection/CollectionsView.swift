import SwiftUI

struct CollectionsView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    @State private var groups: [(Category, [Collection])] = []
    @State private var adding = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if loaded && groups.isEmpty {
                EmptyState(icon: "folder.badge.plus", title: "Group your media", text: "Categories hold collections, like Travel → Kyoto 2025. Start with a category.")
                Button("New category") { adding = true }
                    .buttonStyle(.borderedProminent)
            }
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(groups, id: \.0.id) { cat, cols in
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink(value: cat) {
                            HStack(spacing: 4) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name).font(.title2.weight(.bold))
                                    Text(plural(cols.count, "collection")).font(.caption).foregroundStyle(Theme.muted)
                                }
                                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        if cols.isEmpty {
                            NavigationLink(value: cat) {
                                Label("Add the first collection", systemImage: "folder.badge.plus")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(cols) { c in
                                        NavigationLink(value: c) { CollectionCard(collection: c, width: 150) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Theme.bg)
        .navigationTitle("Collections")
        .navigationDestination(for: Category.self) { CategoryView(category: $0) }
        .navigationDestination(for: Collection.self) { CollectionView(collection: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $adding) { NewCategorySheet().presentationDetents([.height(300)]) }
        .refreshable { await load() }
        .task(id: model.version) { await load() }
    }

    private func load() async {
        await model.run { groups = try await client.allCollections() }
        loaded = true
    }
}

struct CollectionCard: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    let collection: Collection
    var width: CGFloat?

    @State private var items: [Media] = []

    private var cover: Media? { items.first { $0.id == collection.coverId } ?? items.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let cover {
                    Thumbnail(media: cover, maxPixel: 500)
                } else {
                    Theme.surface.overlay {
                        Image(systemName: "photo").font(.title).foregroundStyle(Theme.raised)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .card(radius: 16)
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            Text(collection.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(plural(items.count, "item")).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(width: width)
        .task(id: "\(collection.id)-\(model.version)") {
            items = (try? await client.media(collectionId: collection.id)) ?? []
        }
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
