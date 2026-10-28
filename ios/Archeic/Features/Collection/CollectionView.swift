import SwiftUI

struct CollectionView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let collection: Collection

    @State private var items: [Media] = []
    @State private var children: [Collection] = []
    @State private var selecting = false
    @State private var adding = false
    @State private var confirming = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if !children.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(children) { c in
                            NavigationLink(value: c) { CollectionCard(collection: c, width: 130) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            if loaded && items.isEmpty {
                EmptyState(icon: "photo.on.rectangle", title: "No media yet", text: "Tap + to upload straight into this collection, or add from the library.")
            } else {
                MediaGrid(items: items, grouped: false, collectionId: collection.id, selecting: $selecting)
            }
        }
        .background(Theme.bg)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { UploadButton(collectionId: collection.id) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { selecting.toggle() } label: {
                        Label(selecting ? "Done selecting" : "Select", systemImage: "checkmark.circle")
                    }
                    .disabled(items.isEmpty)
                    Button { adding = true } label: { Label("New sub-collection", systemImage: "folder.badge.plus") }
                    Button(role: .destructive) { confirming = true } label: { Label("Delete collection", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $adding) {
            NameSheet(title: "New sub-collection", placeholder: "Day 1, Episode 2…") { name in
                await model.run {
                    _ = try await client.createCollection(categoryId: collection.categoryId, parentId: collection.id, name: name)
                    model.refresh()
                }
            }
        }
        .confirmationDialog("Delete \(collection.name)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.run {
                        try await client.deleteCollection(collection.id)
                        model.refresh()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Sub-collections are deleted too. Media stays in the library.")
        }
        .task(id: model.version) {
            await model.run {
                items = try await client.media(collectionId: collection.id)
                children = try await client.collections(categoryId: collection.categoryId, parentId: collection.id)
            }
            loaded = true
        }
    }
}

struct CollectionPicker: View {
    @Environment(Client.self) private var client
    @Environment(\.dismiss) private var dismiss
    let title: String
    var exclude: String?
    let pick: (Collection) async -> Void

    @State private var groups: [(Category, [Collection])] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.0.id) { cat, cols in
                    Section(cat.name) {
                        ForEach(cols.filter { $0.id != exclude }) { c in
                            Button {
                                Task {
                                    await pick(c)
                                    dismiss()
                                }
                            } label: {
                                Label(c.name, systemImage: "folder")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { groups = (try? await client.allCollections()) ?? [] }
        }
    }
}
