import SwiftUI

struct ConnectView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    let onConnected: () -> Void

    @State private var address = ""
    @State private var error: String?
    @State private var connecting = false

    var body: some View {
        ZStack {
            Aurora().ignoresSafeArea().opacity(0.6)
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                Text("archeic")
                    .font(.system(size: 64, weight: .heavy))
                    .tracking(-3)
                    .foregroundStyle(Theme.gradient)
                Text("Where is your server?")
                    .font(.title3.weight(.semibold))
                Text("archeic runs on your local network. Pick the address of the machine running it.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                Menu {
                    Picker("Server", selection: $address) {
                        ForEach(Client.knownServers, id: \.self) { s in
                            Text(Self.host(s)).tag(s)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "network").foregroundStyle(Theme.muted)
                        Text(Self.host(address)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }

                Button(action: connect) {
                    HStack {
                        if connecting { ProgressView().tint(.black) }
                        Text(connecting ? "Connecting…" : "Connect").font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(connecting || address.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Spacer()
            }
            .padding(24)
        }
        .background(Theme.bg)
        .onAppear { address = Client.defaultServer }
    }

    private func connect() {
        let normalized = Self.normalize(address)
        guard !normalized.isEmpty, !connecting else { return }
        connecting = true
        error = nil
        Task {
            let previous = client.server
            client.server = normalized
            do {
                _ = try await client.media()
                address = normalized
                model.refresh()
                onConnected()
            } catch {
                client.server = previous
                self.error = "Couldn't reach \(normalized): \(error.localizedDescription)"
            }
            connecting = false
        }
    }

    static func host(_ server: String) -> String {
        URL(string: server)?.host() ?? server
    }

    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        guard !s.isEmpty else { return "" }
        if !s.contains("://") { s = "https://" + s }
        if let url = URL(string: s), url.port == nil, url.scheme == "https" { s += ":8443" }
        return s
    }
}
