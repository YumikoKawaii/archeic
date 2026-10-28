import SwiftUI

struct SettingsView: View {
    @Environment(Client.self) private var client
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var server = ""
    @State private var status: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Client.defaultServer, text: $server)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    Text(status ?? "Address of the archeic nginx, including https:// and the port.")
                }
                Section {
                    Button("Test connection") {
                        Task {
                            client.server = server
                            do {
                                let n = try await client.media().count
                                status = "Connected · \(plural(n, "item"))"
                            } catch {
                                status = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        client.server = server
                        model.refresh()
                        dismiss()
                    }
                }
            }
            .onAppear { server = client.server }
        }
    }
}
