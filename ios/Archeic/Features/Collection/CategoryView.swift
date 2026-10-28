import SwiftUI

struct CategoryView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let category: Category

    @State private var collections: [Collection] = []
    @State private var adding = false
    @State private var confirming = false
    @State private var loaded = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            if loaded && collections.isEmpty {
                EmptyState(icon: "folder", title: "No collections yet", text: "Create one, then add photos and videos to it.")
            }
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(collections) { c in
                    NavigationLink(value: c) { CollectionCard(collection: c) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(category.name)
        .navigationSubtitle("\(category.layout?.label ?? "Gallery") · \(plural(collections.count, "collection"))")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { adding = true } label: { Label("New collection", systemImage: "folder.badge.plus") }
                    Button(role: .destructive) { confirming = true } label: { Label("Delete category", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $adding) {
            NameSheet(title: "New collection", placeholder: "Kyoto 2025, Season 1…") { name in
                await model.run {
                    _ = try await client.createCollection(categoryId: category.id, parentId: nil, name: name)
                    model.refresh()
                }
            }
        }
        .confirmationDialog("Delete \(category.name)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.run {
                        try await client.deleteCategory(category.id)
                        model.refresh()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Its collections are deleted too. Media stays in the library.")
        }
        .task(id: model.version) {
            await model.run { collections = try await client.collections(categoryId: category.id) }
            loaded = true
        }
    }
}
