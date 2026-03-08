import SwiftUI

@main
struct OneHomeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                MainTabView()
                    .environment(appState)
            } else {
                LoginView()
                    .environment(appState)
            }
        }
    }
}
