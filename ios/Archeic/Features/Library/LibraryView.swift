import SwiftUI

struct LibraryView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    @State private var items: [Media] = []
    @State private var filter: Kind = .unspecified
    @State private var selecting = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            Picker("Show", selection: $filter) {
                Text("All").tag(Kind.unspecified)
                Text("Photos").tag(Kind.image)
                Text("Videos").tag(Kind.video)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if loaded && items.isEmpty {
                EmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: filter == .unspecified ? "Your library is empty" : "Nothing here",
                    text: "Tap + to upload photos and videos. They're stored as-is, without compression."
                )
            } else {
                MediaGrid(items: items, selecting: $selecting)
            }
        }
        .background(Theme.bg)
        .navigationTitle("Library")
        .navigationSubtitle(countLabel(items))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selecting ? "Done" : "Select") { selecting.toggle() }
                    .disabled(items.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) { UploadButton() }
        }
        .refreshable { await load() }
        .task(id: "\(filter.rawValue)-\(model.version)") { await load() }
    }

    private func load() async {
        await model.run { items = try await client.media(kind: filter) }
        loaded = true
    }
}
