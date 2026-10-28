import PhotosUI
import SwiftUI

struct RootView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model

    @State private var tab = 0

    private let tabs = [("Home", "house.fill"), ("Library", "square.grid.2x2.fill"), ("Collections", "folder.fill")]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page(0) { HomeView(tab: $tab) }
                page(1) { LibraryView() }
                page(2) { CollectionsView() }
            }
            if !model.tabsHidden { tabBar }
        }
        .overlay(alignment: .top) { banner }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func page(_ index: Int, @ViewBuilder content: () -> some View) -> some View {
        NavigationStack { content() }
            .opacity(tab == index ? 1 : 0)
            .allowsHitTesting(tab == index)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button { tab = i } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[i].1)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 24)
                        Text(tabs[i].0).font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(tab == i ? Theme.accent : Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.raised).frame(height: 1) }
    }

    @ViewBuilder
    private var banner: some View {
        if let up = model.uploading {
            Label("Uploading \(up.done + 1 > up.total ? up.total : up.done + 1) of \(up.total)…", systemImage: "arrow.up.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.raised, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let notice = model.notice {
            Text(notice)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.raised, in: Capsule())
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
