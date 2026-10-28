import PhotosUI
import SwiftUI

struct RootView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                NavigationStack { HomeView(tab: $tab) }
            }
            Tab("Library", systemImage: "square.grid.2x2.fill", value: 1) {
                NavigationStack { LibraryView() }
            }
            Tab("Collections", systemImage: "folder.fill", value: 2) {
                NavigationStack { CollectionsView() }
            }
        }
        .overlay(alignment: .top) { banner }
        .background(Theme.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private var banner: some View {
        if let up = model.uploading {
            Label("Uploading \(up.done + 1 > up.total ? up.total : up.done + 1) of \(up.total)…", systemImage: "arrow.up.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let notice = model.notice {
            Text(notice)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct UploadButton: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    var collectionId: String?

    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $picked, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
        }
        .disabled(model.uploading != nil)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await model.upload(items, client: client, into: collectionId) }
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(Theme.muted)
                .frame(width: 72, height: 72)
                .background(Theme.surface, in: Circle())
            Text(title).font(.title3.weight(.semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
