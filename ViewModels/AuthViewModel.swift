import SwiftUI

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var username = ""
    var name = ""
    var errorMessage: String?
    var isLoading = false

    func signIn(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Fill in all fields 😤"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.signIn(email: email, password: password)
            await appState.checkAuth()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !name.isEmpty else {
            errorMessage = "Don't leave fields empty, champ 🙄"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let user = try await AuthService.shared.signUp(email: email, password: password, username: username, name: name)
            appState.currentUser = user
            appState.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
