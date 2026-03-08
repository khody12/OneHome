import Supabase
import Foundation

/// Handles sign up, sign in, sign out, and session management
class AuthService {
    static let shared = AuthService()
    private init() {}

    // Sign up with email and password, then insert a user profile row
    func signUp(email: String, password: String, username: String, name: String) async throws -> User {
        let session = try await supabase.auth.signUp(email: email, password: password)
        let userID = session.user.id

        let newUser = UserInsert(id: userID, username: username, name: name, email: email)
        try await supabase.from("users").insert(newUser).execute()

        return User(id: userID, username: username, name: name, email: email, avatarURL: nil, createdAt: Date())
    }

    // Sign in with email or username + password
    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // Fetch the current logged-in user's profile
    func currentUser() async throws -> User? {
        guard let authUser = try? await supabase.auth.user() else { return nil }
        let users: [User] = try await supabase
            .from("users")
            .select()
            .eq("id", value: authUser.id)
            .limit(1)
            .execute()
            .value
        return users.first
    }

    var isLoggedIn: Bool {
        get async {
            (try? await supabase.auth.user()) != nil
        }
    }
}

// Minimal insert struct for creating user rows
private struct UserInsert: Encodable {
    let id: UUID
    let username: String
    let name: String
    let email: String
}
