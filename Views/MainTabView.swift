import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if let home = appState.currentHome {
            TabView {
                FeedView(home: home)
                    .tabItem { Label("Feed", systemImage: "house.fill") }

                CameraTabView(home: home)
                    .tabItem { Label("Post", systemImage: "camera.fill") }

                MetricsView(home: home, currentUserID: appState.currentUser?.id ?? UUID())
                    .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }

                HomeSelectionView()
                    .tabItem { Label("Homes", systemImage: "building.2.fill") }
            }
            .tint(.orange)
        } else {
            HomeSelectionView()
        }
    }
}
