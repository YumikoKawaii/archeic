import SwiftUI

struct MediaGrid: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    let items: [Media]
    var grouped = true
    var collectionId: String?
    @Binding var selecting: Bool

    @State private var selected: Set<String> = []
    @State private var viewing: Media?
    @State private var picking = false
    @State private var sections: [DaySection] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: grouped ? [.sectionHeaders] : []) {
            if grouped {
                ForEach(sections) { section in
                    Section {
                        grid(section.items)
                    } header: {
                        Text(section.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.bg.opacity(0.92))
                    }
                }
            } else {
                grid(items)
            }
        }
        .onChange(of: selecting) { _, on in
            if !on { selected = [] }
            model.tabsHidden = on
        }
        .onDisappear { if selecting { model.tabsHidden = false } }
        .onChange(of: items, initial: true) { _, list in
            if grouped { sections = groupByDay(list) }
        }
        .fullScreenCover(item: $viewing) { m in
            Viewer(items: items, start: m, collectionId: collectionId)
        }
        .sheet(isPresented: $picking) {
            CollectionPicker(title: "Add \(plural(selected.count, "item")) to…", exclude: collectionId) { target in
                let ids = Array(selected)
                await model.run {
                    try await client.addItems(collectionId: target.id, mediaIds: ids)
                    model.notify("Added to \(target.name)")
                    selecting = false
                    model.refresh()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            if selecting {
                ToolbarItemGroup(placement: .bottomBar) { selectionBar }
            }
        }    }

    private func grid(_ list: [Media]) -> some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(list) { m in
                Thumbnail(media: m)
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(selected.contains(m.id) ? 0.88 : 1)
                    .card(radius: selected.contains(m.id) ? 10 : 2)
                    .overlay(alignment: .topTrailing) {
                        if selecting {
                            Image(systemName: selected.contains(m.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected.contains(m.id) ? Theme.accent : .white)
                                .shadow(radius: 3)
                                .padding(6)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { tap(m) }
                    .animation(.spring(duration: 0.25), value: selected)
            }
        }
    }

    private func tap(_ m: Media) {
        guard selecting else {
            viewing = m
            return
        }
        if selected.contains(m.id) { selected.remove(m.id) } else { selected.insert(m.id) }
    }

    private var selectionBar: some View {
        HStack {
            Button {
                picking = true
            } label: {
                Label("Add to", systemImage: "folder.badge.plus")
            }
            .frame(maxWidth: .infinity)
            if let collectionId {
                Button {
                    let ids = Array(selected)
                    Task {
                        await model.run {
                            try await client.removeItems(collectionId: collectionId, mediaIds: ids)
                            selecting = false
                            model.refresh()
                        }
                    }
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
                .frame(maxWidth: .infinity)
            }
            DeleteButton(count: selected.count) {
                let ids = Array(selected)
                await model.run {
                    for id in ids { try await client.deleteMedia(id) }
                    model.notify("Deleted \(plural(ids.count, "item"))")
                    selecting = false
                    model.refresh()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.subheadline.weight(.semibold))
        .disabled(selected.isEmpty)
    }
}

struct DeleteButton: View {
    let count: Int
    let action: () async -> Void

    @State private var confirming = false

    var body: some View {
        Button(role: .destructive) {
            confirming = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(Theme.danger)
        .confirmationDialog("Delete \(plural(count, "item")) permanently?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await action() } }
        } message: {
            Text("Files are removed from storage. This can't be undone.")
        }
    }
}
