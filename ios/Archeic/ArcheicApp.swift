import SwiftUI

@main
struct ArcheicApp: App {
    @State private var client = Client()
    @State private var model = AppModel()
    @State private var connected = false

    var body: some Scene {
        WindowGroup {
            Group {
                if connected {
                    RootView().transition(.opacity)
                } else {
                    ConnectView { withAnimation(.easeOut(duration: 0.35)) { connected = true } }
                }
            }
                .environment(client)
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
