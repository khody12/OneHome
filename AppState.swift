import SwiftUI

/// Global app state — current user, selected home, auth status
@Observable
class AppState {
    var currentUser: User?
    var currentHome: Home?
    var isAuthenticated: Bool = false
    var pendingInviteCount: Int = 0

    init() {
        Task { await checkAuth() }
    }

    func checkAuth() async {
        currentUser = try? await AuthService.shared.currentUser()
        isAuthenticated = currentUser != nil
        if let userID = currentUser?.id {
            let invites = try? await InviteService.shared.fetchPendingInvites(for: userID)
            pendingInviteCount = invites?.count ?? 0
        }
    }

    func signOut() async {
        try? await AuthService.shared.signOut()
        currentUser = nil
        currentHome = nil
        isAuthenticated = false
    }

#if DEBUG
    // Bypasses Supabase entirely — loads fake data straight into the app
    func devLogin() {
        currentUser = DevPreview.user
        currentHome = DevPreview.home
        isAuthenticated = true
    }
#endif
}
