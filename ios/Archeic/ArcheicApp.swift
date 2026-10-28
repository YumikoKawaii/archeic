import SwiftUI

@main
struct ArcheicApp: App {
    @State private var client = Client()
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(client)
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
